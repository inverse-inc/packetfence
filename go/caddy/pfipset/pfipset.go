package pfipset

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/go-utils/sharedutils"
)

// Queue value
const (
	maxQueueSize = 1000
	maxWorkers   = 1
)

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("pfipset", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

type PfipsetHandler struct {
	Next     httpserver.Handler
	IPSET    *pfIPSET
	database *sql.DB
	router   *mux.Router
}

// Setup the pfipset middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.Cluster.HostsIp)

	pfipset, err := buildPfipsetHandler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfipset.Next = next
		return pfipset
	})

	return nil
}

func buildPfipsetHandler(ctx context.Context) (PfipsetHandler, error) {

	pfipset := PfipsetHandler{}
	pfipset.IPSET = &pfIPSET{}

	// create job channel
	pfipset.IPSET.jobs = make(chan job, maxQueueSize)

	// create workers
	for i := 1; i <= maxWorkers; i++ {
		go func(i int) {
			for j := range pfipset.IPSET.jobs {
				doWork(i, j)
			}
		}(i)
	}

	go func() {
		ctx := log.LoggerNewContext(context.Background())
		for {
			time.Sleep(1 * time.Second)
			currentQueueSize := len(pfipset.IPSET.jobs)
			// Log a warning when queue is halfway full, and an error when its full
			if currentQueueSize >= maxQueueSize {
				log.LoggerWContext(ctx).Error("Queue has reached its maximum. Ipset related calls will be delayed and may timeout. Investigate previous logs to determine the cause of this backlog.")
			} else if currentQueueSize > (maxQueueSize * 0.5) {
				log.LoggerWContext(ctx).Warn(fmt.Sprintf("Queue has reached %d. Until it reaches %d, everything will still work.", currentQueueSize, maxQueueSize))
			}
		}
	}()

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfipset.IPSET.detectType(ctx)

	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	pfipset.database = db

	// Reload the set from the database each 5 minutes
	// TODO: have this time configurable
	go func() {
		// Create a new context just for this goroutine
		ctx := context.WithValue(ctx, "dummy", "dummy")
		for {
			var Inline bool
			Inline = false
			var keyConfNet pfconfigdriver.PfconfigKeys
			keyConfNet.PfconfigNS = "config::Network"
			keyConfNet.PfconfigHostnameOverlay = "yes"

			pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

			for _, key := range keyConfNet.Keys {
				var ConfNet pfconfigdriver.RessourseNetworkConf
				ConfNet.PfconfigHashNS = key

				pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)

				if ConfNet.Type == "inlinel2" || ConfNet.Type == "inlinel3" || ConfNet.Type == "inline" {
					Inline = true
				}
			}
			if Inline {
				pfipset.IPSET.initIPSet(ctx, pfipset.database)
				log.LoggerWContext(ctx).Info("Reloading ipsets")
			} else {
				log.LoggerWContext(ctx).Info("No Inline Network bypass ipsets reload")
			}
			time.Sleep(300 * time.Second)
		}
	}()

	pfipset.router = mux.NewRouter()
	api := pfipset.router.PathPrefix("/api/v1").Subrouter()
	api.HandleFunc("/ipset/mark_layer3", handleLayer3).Methods("POST")
	api.HandleFunc("/ipset/mark_layer2", handleLayer2).Methods("POST")
	api.HandleFunc("/ipset/unmark_mac", pfipset.IPSET.handleUnmarkMac).Methods("POST")
	api.HandleFunc("/ipset/unmark_ip", pfipset.IPSET.handleUnmarkIp).Methods("POST")
	api.HandleFunc("/ipset/mark_ip_layer2", handleMarkIpL2).Methods("POST")
	api.HandleFunc("/ipset/mark_ip_layer3", handleMarkIpL3).Methods("POST")
	api.HandleFunc("/ipset/passthrough", handlePassthrough).Methods("POST")
	api.HandleFunc("/ipset/passthrough_isolation", handleIsolationPassthrough).Methods("POST")
	api.HandleFunc("/ipset/add_ip/{set_name}", handleAddIp).Methods("POST")
	api.HandleFunc("/ipset/remove_ip/{set_name}", handleRemoveIp).Methods("POST")

	return pfipset, nil
}

func (h PfipsetHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()
	ctx = h.IPSET.AddToContext(ctx)
	r = r.WithContext(ctx)

	defer panichandler.Http(ctx, w)

	routeMatch := mux.RouteMatch{}
	if h.router.Match(r, &routeMatch) {
		h.router.ServeHTTP(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}

}
