package pfpki

import (
	"context"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/handlers"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/models"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
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
	dict, err := models.ParseYAMLDict()
	if err != nil {
		panic(err)
	}
	cat, err := catalog.NewFromMap(dict)
	if err != nil {
		panic(err)
	}
	message.DefaultCatalog = cat
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

func buildPfpkiHandler(ctx context.Context) (types.Handler, error) {

	pfpki := types.Handler{}
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

	pfpki.Ctx = &ctx

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfpki.Router = mux.NewRouter()
	PFPki := &pfpki
	api := pfpki.Router.PathPrefix("/api/v1").Subrouter()

	// CAs (GET: list, POST: create)
	api.Handle("/pki/cas", handlers.GetSetCA(PFPki)).Methods("GET", "POST")
	// Search CAs
	api.Handle("/pki/cas/search", handlers.SearchCA(PFPki)).Methods("POST")
	// Fix CA after Import
	api.Handle("/pki/ca/fix", handlers.FixCA(PFPki)).Methods("GET")
	// Get CA by ID
	api.Handle("/pki/ca/{id}", handlers.GetCAByID(PFPki)).Methods("GET")

	// Profiles (GET: list, POST: create)
	api.Handle("/pki/profiles", handlers.GetSetProfile(PFPki)).Methods("GET", "POST")
	// Search Profiles
	api.Handle("/pki/profiles/search", handlers.SearchProfile(PFPki)).Methods("POST")
	// Profile by ID (GET: get, PATCH: update)
	api.Handle("/pki/profile/{id}", handlers.GetProfileByID(PFPki)).Methods("GET", "PATCH")

	// Certificates (GET: list, POST: create)
	api.Handle("/pki/certs", handlers.GetSetCert(PFPki)).Methods("GET", "POST")
	// Search Certificates
	api.Handle("/pki/certs/search", handlers.SearchCert(PFPki)).Methods("POST")
	// Get Certificate by ID
	api.Handle("/pki/cert/{id}", handlers.GetCertByID(PFPki)).Methods("GET")
	// Download Certificate
	api.Handle("/pki/cert/{id}/download/{password}", handlers.DownloadCert(PFPki)).Methods("GET")
	// Get Certificate by email
	api.Handle("/pki/cert/{id}/email", handlers.EmailCert(PFPki)).Methods("GET")
	// Revoke Certificate
	api.Handle("/pki/cert/{id}/{reason}", handlers.RevokeCert(PFPki)).Methods("DELETE")

	// Revoked Certificates
	api.Handle("/pki/revokedcerts", handlers.GetRevoked(PFPki)).Methods("GET")
	// Search Revoked Certificates
	api.Handle("/pki/revokedcerts/search", handlers.SearchRevoked(PFPki)).Methods("POST")
	// Get Revoked Certificate by ID
	api.Handle("/pki/revokedcert/{id}", handlers.GetRevokedByID(PFPki)).Methods("GET")

	// OCSP responder
	api.Handle("/pki/ocsp", handlers.ManageOcsp(PFPki)).Methods("GET", "POST")

	// SCEP responder
	api.Handle("/scep", handlers.ManageSCEP(PFPki)).Methods("GET", "POST")

	api.Handle("/scep/{id}", handlers.ManageSCEP(PFPki)).Methods("GET", "POST")

	api.Handle("/pki/scep", handlers.ManageSCEP(PFPki)).Methods("GET", "POST")

	api.Handle("/pki/scep/{id}", handlers.ManageSCEP(PFPki)).Methods("GET", "POST")

	api.Handle("/pki/scep/{id}/", handlers.ManageSCEP(PFPki)).Methods("GET", "POST")

	go func() {
		for {
			pfpki.DB.DB().Ping()
			time.Sleep(5 * time.Second)
		}
	}()

	return pfpki, nil
}
