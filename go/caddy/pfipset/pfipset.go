package pfipset

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/database"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
	"github.com/mholt/caddy"
	"github.com/mholt/caddy/caddyhttp/httpserver"
)

// Queue value
const (
	maxQueueSize = 1000
	maxWorkers   = 10
)

type PfipsetHandler struct {
	Next     httpserver.Handler
	router   *httprouter.Router
	IPSET    *pfIPSET
	database *sql.DB
	router   *mux.Router
	jobs     chan job
}

// Setup the pfipset middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfipset, err := buildPfipsetHandler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfipset.Next = next
		return pfipset
	})

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)

	return nil
}

func buildPfipsetHandler() (PfipsetHandler, error) {

	pfipset := PfipsetHandler{}
	pfipset.IPSET = &pfIPSET{}

	// create job channel
	pfipset.jobs = make(chan job, maxQueueSize)

	// create workers
	for i := 1; i <= maxWorkers; i++ {
		go func(i int) {
			for j := range jobs {
				doWork(i, j)
			}
		}(i)
	}

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	IPSET.detectType()

	pfipset.database = database.ConnectFromConfig(pfconfigdriver.Config.PfConf.Database)

	// Reload the set from the database each 5 minutes
	// TODO: have this time configurable
	go func() {
		// Read DB config
		for {
			pfipset.IPSET.initIPSet()
			fmt.Println("Reloading ipsets")
			time.Sleep(300 * time.Second)
		}
	}()

	pfipset.router = mux.NewRouter()
	pfipset.router.HandleFunc("/ipsetmarklayer3/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{type:[a-zA-Z]+}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", handleLayer3).Methods("POST")
	pfipset.router.HandleFunc("/ipsetmarklayer2/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{type:[a-zA-Z]+}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}/{local:[0-1]}", handleLayer2).Methods("POST")
	pfipset.router.HandleFunc("/ipsetunmarkmac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}/{local:[0-1]}", IPSET.handleUnmarkMac).Methods("POST")
	pfipset.router.HandleFunc("/ipsetunmarkip/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", IPSET.handleUnmarkIp).Methods("POST")
	pfipset.router.HandleFunc("/ipsetmarkiplayer2/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", handleMarkIpL2).Methods("POST")
	pfipset.router.HandleFunc("/ipsetmarkiplayer3/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", handleMarkIpL3).Methods("POST")
	pfipset.router.HandleFunc("/ipsetpassthrough/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{port:(?:udp|tcp):[0-9]+}/{local:[0-1]}", handlePassthrough).Methods("POST")
	pfipset.router.HandleFunc("/ipsetpassthroughisolation/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{port:(?:udp|tcp):[0-9]+}/{local:[0-1]}", handleIsolationPassthrough).Methods("POST")
}

func (h PfipsetHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	routeMatch := mux.RouteMatch{}
	if h.router.Match(r, &routeMatch) {
		routeMatch.Handler(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}

}
