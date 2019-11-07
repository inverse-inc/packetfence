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

// Handler struct
type Handler struct {
	Next   httpserver.Handler
	router *mux.Router
	DB     *gorm.DB
	Ctx    context.Context
}

// Setup the pfpki middleware
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfpki, err := buildPfpkiHandler(ctx)

	sharedutils.CheckError(err)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfpki.Next = next
		return pfpki
	})

	return nil
}

func buildPfpkiHandler(ctx context.Context) (Handler, error) {

	pfpki := Handler{}

	Database, err := gorm.Open("mysql", db.ReturnURI(ctx))
	sharedutils.CheckError(err)
	pfpki.DB = Database
	pfpki.Ctx = ctx

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfpki.router = mux.NewRouter()
	PFPki := &pfpki
	api := pfpki.router.PathPrefix("/api/v1").Subrouter()
	api.Handle("/pki/newca", manageCA(PFPki)).Methods("POST")
	api.Handle("/pki/getca/{cn}", manageCA(PFPki)).Methods("GET")
	// api.Handle("/pki/listca", listCA(PFPki)).Methods("GET")
	api.Handle("/pki/newprofile", manageProfile(PFPki)).Methods("POST")
	api.Handle("/pki/newcert", manageCert(PFPki)).Methods("POST")
	api.Handle("/pki/getcert/{cn}", manageCert(PFPki)).Methods("GET")
	api.Handle("/pki/getcert/{cn}/{password}", manageCert(PFPki)).Methods("GET")

	api.Handle("/pki/revokecert/{cn}/{reason}", manageCert(PFPki)).Methods("GET")
	api.Handle("/pki/ocsp", manageOcsp(PFPki)).Methods("GET", "POST")
	// api.Handle("/pki/listcert", getCert(PFPki)).Methods("GET")

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
