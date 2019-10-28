package pfpki

import (
	"context"
	"database/sql"
	"net/http"
	"time"

	// Because i want it
	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("pfpki", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

// Handler struct
type Handler struct {
	Next     httpserver.Handler
	database *sql.DB
	router   *mux.Router
}

// Setup the pfipset middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.Cluster.HostsIp)

	pfpki, err := buildHandler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfipset.Next = next
		return pfpki
	})

	return nil
}

func buildHandler(ctx context.Context) (PfpkiHandler, error) {

	pfpki := Handler{}

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	pfpki.database = db

	pfpki.router = mux.NewRouter()
	api := pfpki.router.PathPrefix("/api/v1").Subrouter()
	api.HandleFunc("/pki/new_ca", newCA).Methods("POST")

	return pfpki, nil
}

func (h PfpkiHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()
	ctx = h.IPSET.AddToContext(ctx)
	r = r.WithContext(ctx)

	defer panichandler.Http(ctx, w)

	routeMatch := mux.RouteMatch{}
	if h.router.Match(r, &routeMatch) {
		h.router.ServeHTTP(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	}
	return h.Next.ServeHTTP(w, r)
}
