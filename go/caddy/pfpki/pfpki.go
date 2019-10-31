package pfpki

import (
	"context"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/jinzhu/gorm"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("pfpki", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

var database *gorm.DB

// Handler struct
type Handler struct {
	Next   httpserver.Handler
	router *mux.Router
}

// Setup the pfpki middleware
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.Cluster.HostsIp)

	pfpki, err := Handler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfpki.Next = next
		return pfpki
	})

	return nil
}

func buildPfipsetHandler(ctx context.Context) (Handler, error) {

	pfpki := Handler{}

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	database, err := gorm.Open("mysql", db.ReturnURI)
	sharedutils.CheckError(err)

	pfpki.router = mux.NewRouter()
	api := pfpki.router.PathPrefix("/api/v1").Subrouter()
	api.HandleFunc("/pki/newca", newCA).Methods("POST")
	api.HandleFunc("/pki/newprofile", newProfile).Methods("POST")
	api.HandleFunc("/pki/newcert", newCert).Methods("POST")

	return pfpki, nil
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()
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
