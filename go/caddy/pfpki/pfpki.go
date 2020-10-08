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

var successDBConnect = false

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
	var Database *gorm.DB
	var err error

	for !successDBConnect {
		Database, err = gorm.Open("mysql", db.ReturnURIFromConfig(ctx))
		if err != nil {
			time.Sleep(time.Duration(5) * time.Second)
		} else {
			successDBConnect = true
		}
	}

	gorm.DefaultTableNameHandler = func(Database *gorm.DB, defaultTableName string) string {
		return "pki_" + defaultTableName
	}
	if log.LoggerGetLevel(ctx) == "DEBUG" {
		pfpki.DB = Database.Debug()
	} else {
		pfpki.DB = Database
	}

	pfpki.Ctx = ctx

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfpki.router = mux.NewRouter()
	PFPki := &pfpki
	api := pfpki.router.PathPrefix("/api/v1").Subrouter()

	// CAs (GET: list, POST: create)
	api.Handle("/pki/cas", getSetCA(PFPki)).Methods("GET", "POST")
	// Search CAs
	api.Handle("/pki/cas/search", searchCA(PFPki)).Methods("POST")
	// Fix CA after Import
	api.Handle("/pki/ca/fix", fixCA(PFPki)).Methods("GET")
	// Get CA by ID
	api.Handle("/pki/ca/{id}", getCAByID(PFPki)).Methods("GET")

	// Profiles (GET: list, POST: create)
	api.Handle("/pki/profiles", getSetProfile(PFPki)).Methods("GET", "POST")
	// Search Profiles
	api.Handle("/pki/profiles/search", searchProfile(PFPki)).Methods("POST")
	// Profile by ID (GET: get, PATCH: update)
	api.Handle("/pki/profile/{id}", getProfileByID(PFPki)).Methods("GET", "PATCH")

	// Certificates (GET: list, POST: create)
	api.Handle("/pki/certs", getSetCert(PFPki)).Methods("GET", "POST")
	// Search Certificates
	api.Handle("/pki/certs/search", searchCert(PFPki)).Methods("POST")
	// Get Certificate by ID
	api.Handle("/pki/cert/{id}", getCertByID(PFPki)).Methods("GET")
	// Download Certificate
	api.Handle("/pki/cert/{id}/download/{password}", downloadCert(PFPki)).Methods("GET")
	// Download Certificate from profile
	api.Handle("/pki/cert/{profile}/{id}/download/{password}", downloadCert(PFPki)).Methods("GET")
	// Get Certificate by email
	api.Handle("/pki/cert/{id}/email", emailCert(PFPki)).Methods("GET")
	// Revoke Certificate
	api.Handle("/pki/cert/{id}/{reason}", revokeCert(PFPki)).Methods("DELETE")
	// Revoke Certificate from serial
	api.Handle("/pki/cert/{serial}/{id}/{reason}", revokeCert(PFPki)).Methods("DELETE")
	// Revoked Certificates
	api.Handle("/pki/revokedcerts", getRevoked(PFPki)).Methods("GET")
	// Search Revoked Certificates
	api.Handle("/pki/revokedcerts/search", searchRevoked(PFPki)).Methods("POST")
	// Get Revoked Certificate by ID
	api.Handle("/pki/revokedcert/{id}", getRevokedByID(PFPki)).Methods("GET")

	// OCSP responder
	api.Handle("/pki/ocsp", manageOcsp(PFPki)).Methods("GET", "POST")

	go func() {
		for {
			pfpki.DB.DB().Ping()
			time.Sleep(5 * time.Second)
		}
	}()

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
