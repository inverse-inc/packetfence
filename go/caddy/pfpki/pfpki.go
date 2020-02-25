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
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("pfpki", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
	dict, err := parseYAMLDict()
	if err != nil {
		panic(err)
	}
	cat, err := catalog.NewFromMap(dict)
	if err != nil {
		panic(err)
	}
	message.DefaultCatalog = cat
}

type (
	// Handler struct
	Handler struct {
		Next   httpserver.Handler
		router *mux.Router
		DB     *gorm.DB
		Ctx    context.Context
	}
)

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

	Database, err := gorm.Open("mysql", db.ReturnURI(ctx, "pf"))
	sharedutils.CheckError(err)
	//pfpki.DB = Database

	gorm.DefaultTableNameHandler = func(Database *gorm.DB, defaultTableName string) string {
		return "pki_" + defaultTableName
	}

	pfpki.DB = Database.Debug()
	pfpki.Ctx = ctx

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfpki.router = mux.NewRouter()
	PFPki := &pfpki
	api := pfpki.router.PathPrefix("/api/v1").Subrouter()

	// CAs (GET: list, POST: create)
	api.Handle("/pki/cas", manageCA(PFPki)).Methods("GET", "POST")
	// Search CAs
	api.Handle("/pki/cas/search", manageCA(PFPki)).Methods("POST")
	// Get CA by ID
	api.Handle("/pki/ca/{id}", manageCA(PFPki)).Methods("GET")

	// Profiles (GET: list, POST: create)
	api.Handle("/pki/profiles", manageProfile(PFPki)).Methods("GET", "POST")
	// Search Profiles
	api.Handle("/pki/profiles/search", manageProfile(PFPki)).Methods("POST")
	// Profile by ID (GET: get, PATCH: update)
	api.Handle("/pki/profile/{id}", manageProfile(PFPki)).Methods("GET", "PATCH")

	// Certificates (GET: list, POST: create)
	api.Handle("/pki/certs", manageCert(PFPki)).Methods("GET", "POST")
	// Search Certificates
	api.Handle("/pki/certs/search", manageCert(PFPki)).Methods("POST")
	// Get Certificate by ID
	api.Handle("/pki/cert/{id}", manageCert(PFPki)).Methods("GET")
	// Download Certificate
	api.Handle("/pki/cert/{id}/download/{password}", manageCert(PFPki)).Methods("GET")
	// Get Certificate by email
	api.Handle("/pki/cert/{id}/email", manageCert(PFPki)).Methods("GET")
	// Revoke Certificate
	api.Handle("/pki/cert/{id}/{reason}", manageCert(PFPki)).Methods("DELETE")

	// Revoked Certificates
	api.Handle("/pki/revokedcerts", manageRevokedCert(PFPki)).Methods("GET")
	// Search Revoked Certificates
	api.Handle("/pki/revokedcerts/search", manageRevokedCert(PFPki)).Methods("POST")
	// Get Revoked Certificate by ID
	api.Handle("/pki/revokedcert/{id}", manageRevokedCert(PFPki)).Methods("GET")

	// OCSP responder
	api.Handle("/pki/ocsp", manageOcsp(PFPki)).Methods("GET", "POST")

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
