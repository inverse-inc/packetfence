package pfpki

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/handlers"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/jinzhu/gorm"
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(Handler{})
	httpcaddyfile.RegisterHandlerDirective("pfpki", caddy2.ParseCaddyfile[Handler])
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

func (h Handler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.pfpki",
		New: func() caddy.Module { return &Handler{} },
	}
}

type Handler struct {
	caddy2.ModuleBase
	pfpki types.Handler
}

// Setup the pfpki middleware
func (h *Handler) Provision(ctx caddy.Context) error {
	ctx2 := log.LoggerNewContext(context.Background())
	err := buildPfpkiHandler(&h.pfpki, ctx2)
	sharedutils.CheckError(err)
	return nil
}

func buildPfpkiHandler(pfpki *types.Handler, ctx context.Context) error {

	var Database *gorm.DB
	var err error

	var successDBConnect = false
	for !successDBConnect {
		Database, err = gorm.Open("mysql", db.ReturnURIFromConfig(ctx))
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to connect to the database: %s", err))
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
	api := pfpki.Router.PathPrefix("/api/v1").Subrouter()

	// CAs (GET: list, POST: create)
	api.Handle("/pki/cas", handlers.GetSetCA(pfpki)).Methods("GET", "POST")
	// Search CAs
	api.Handle("/pki/cas/search", handlers.SearchCA(pfpki)).Methods("POST")
	// Fix CA after Import
	api.Handle("/pki/ca/fix", handlers.FixCA(pfpki)).Methods("GET")
	// Get CA by ID
	api.Handle("/pki/ca/{id}", handlers.GetCAByID(pfpki)).Methods("GET")
	// Resign CA
	api.Handle("/pki/ca/resign/{id}", handlers.ResignCA(pfpki)).Methods("POST")

	// Profiles (GET: list, POST: create)
	api.Handle("/pki/profiles", handlers.GetSetProfile(pfpki)).Methods("GET", "POST")
	// Search Profiles
	api.Handle("/pki/profiles/search", handlers.SearchProfile(pfpki)).Methods("POST")
	// Profile by ID (GET: get, PATCH: update)
	api.Handle("/pki/profile/{id}", handlers.GetProfileByID(pfpki)).Methods("GET", "PATCH")
	// Sign a CSR
	api.Handle("/pki/profile/{id}/sign_csr", handlers.SignCSR(pfpki)).Methods("POST")

	// Certificates (GET: list, POST: create)
	api.Handle("/pki/certs", handlers.GetSetCert(pfpki)).Methods("GET", "POST")
	// Search Certificates
	api.Handle("/pki/certs/search", handlers.SearchCert(pfpki)).Methods("POST")
	// Get Certificate by ID
	api.Handle("/pki/cert/{id}", handlers.GetCertByID(pfpki)).Methods("GET")
	// Download Certificate
	api.Handle("/pki/cert/{id}/download/{password}", handlers.DownloadCert(pfpki)).Methods("GET")
	// Download Certificate from profile
	api.Handle("/pki/cert/{profile}/{id}/download/{password}", handlers.DownloadCert(pfpki)).Methods("GET")
	// Get Certificate by email
	api.Handle("/pki/cert/{id}/email", handlers.EmailCert(pfpki)).Methods("GET")
	// Revoke Certificate
	api.Handle("/pki/cert/{id}/{reason}", handlers.RevokeCert(pfpki)).Methods("DELETE")

	// Revoke Certificate from profile
	api.Handle("/pki/cert/{profile}/{cn}/{reason}", handlers.RevokeCert(pfpki)).Methods("DELETE")
	// Revoked Certificates
	api.Handle("/pki/revokedcerts", handlers.GetRevoked(pfpki)).Methods("GET")
	// Search Revoked Certificates
	api.Handle("/pki/revokedcerts/search", handlers.SearchRevoked(pfpki)).Methods("POST")
	// Get Revoked Certificate by ID
	api.Handle("/pki/revokedcert/{id}", handlers.GetRevokedByID(pfpki)).Methods("GET")

	api.Handle("/pki/checkrenewal", handlers.CheckRenewal(pfpki)).Methods("GET")

	// OCSP responder
	api.Handle("/pki/ocsp", handlers.ManageOcsp(pfpki)).Methods("GET", "POST")

	// SCEP responder
	api.Handle("/scep", handlers.ManageSCEP(pfpki)).Methods("GET", "POST")

	api.Handle("/scep/{id}", handlers.ManageSCEP(pfpki)).Methods("GET", "POST")

	api.Handle("/scep/{id}/pkiclient.exe", handlers.ManageSCEP(pfpki)).Methods("GET", "POST")

	api.Handle("/pki/scep", handlers.ManageSCEP(pfpki)).Methods("GET", "POST")

	api.Handle("/pki/scep/{id}", handlers.ManageSCEP(pfpki)).Methods("GET", "POST")

	api.Handle("/pki/scep/{id}/pkiclient.exe", handlers.ManageSCEP(pfpki)).Methods("GET", "POST")

	api.Handle("/pki/scep/{id}/", handlers.ManageSCEP(pfpki)).Methods("GET", "POST")

	go func() {
		for {
			pfpki.DB.DB().Ping()
			time.Sleep(5 * time.Second)
		}
	}()

	return nil
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()
	r = r.WithContext(ctx)

	defer panichandler.Http(ctx, w)

	routeMatch := mux.RouteMatch{}
	if h.pfpki.Router.Match(r, &routeMatch) {
		h.pfpki.Router.ServeHTTP(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return nil
	}
	return next.ServeHTTP(w, r)
}
