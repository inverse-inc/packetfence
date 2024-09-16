package pfpki

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	chi "github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/handlers"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type Handler struct {
	Handler   types.Handler
	cancelCtx context.Context
	cancel    func()
}

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(Handler{})
	httpcaddyfile.RegisterHandlerDirective("pfpki", utils.ParseCaddyfile[Handler])

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

// CaddyModule returns the Caddy module information.
func (Handler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.pfpki",
		New: func() caddy.Module {
			return &Handler{}
		},
	}
}

// Setup the pfpki middleware
func (m *Handler) Provision(_ caddy.Context) error {
	m.cancelCtx, m.cancel = context.WithCancel(context.Background())
	ctx := log.LoggerNewContext(context.Background())

	err := m.buildPfpkiHandler(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (h *Handler) buildPfpkiHandler(ctx context.Context) error {

	pfpki := types.Handler{}
	var Database *gorm.DB
	var err error

	var successDBConnect = false
	for !successDBConnect {
		Database, err = gorm.Open(mysql.Open(db.ReturnURIFromConfig(ctx)), &gorm.Config{})
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to connect to the database: %s", err))
			time.Sleep(time.Duration(5) * time.Second)
		} else {
			successDBConnect = true
		}
	}

	if log.LoggerGetLevel(ctx) == "DEBUG" {
		pfpki.DB = Database.Debug()
	} else {
		pfpki.DB = Database
	}

	pfpki.Ctx = &ctx

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	PFPki := &pfpki

	r.Route("/api/v1", func(r chi.Router) {
		// CAS api endpoint
		r.Route("/pki/cas", func(r chi.Router) {
			r.Get("/", handlers.GetSetCA(PFPki))
			r.Post("/", handlers.GetSetCA(PFPki))
			r.Post("/search", handlers.SearchCA(PFPki))
		})
		// CA api endpoint
		r.Route("/pki/ca", func(r chi.Router) {
			r.Get("/fix", handlers.FixCA(PFPki))
			r.Get("/{id}", handlers.CAByID(PFPki))
			r.Patch("/{id}", handlers.CAByID(PFPki))
			r.Post("/resign/{id}", handlers.ResignCA(PFPki))
			r.Post("/csr/{id}", handlers.GenerateCSR(PFPki))
		})
		// Profiles api endpoint
		r.Route("/pki/profiles", func(r chi.Router) {
			r.Post("/", handlers.GetSetProfile(PFPki))
			r.Get("/", handlers.GetSetProfile(PFPki))
			r.Post("/search", handlers.SearchProfile(PFPki))
		})
		// Profile api endpoint
		r.Route("/pki/profile", func(r chi.Router) {
			r.Patch("/{id}", handlers.GetProfileByID(PFPki))
			r.Get("/{id}", handlers.GetProfileByID(PFPki))
			r.Post("/{id}/sign_csr", handlers.SignCSR(PFPki))

		})
		// Certs api endpoint
		r.Route("/pki/certs", func(r chi.Router) {
			r.Post("/", handlers.GetSetCert(PFPki))
			r.Get("/", handlers.GetSetCert(PFPki))
			r.Post("/search", handlers.SearchCert(PFPki))
		})
		// Cert api endpoint
		r.Route("/pki/cert", func(r chi.Router) {
			r.Get("/{id}", handlers.GetCertByID(PFPki))
			r.Get("/{id}/download/{password}", handlers.DownloadCert(PFPki))
			r.Get("/{profile}/{id}/download/{password}", handlers.DownloadCert(PFPki))
			r.Get("/{id}/email", handlers.EmailCert(PFPki))
			r.Delete("/{id}/{reason}", handlers.RevokeCert(PFPki))
			r.Post("/resign/{id}", handlers.ResignCert(PFPki))
			r.Delete("/{profile}/{cn}/{reason}", handlers.RevokeCert(PFPki))
		})
		// Revoke certs api endpoint
		r.Route("/pki/revokedcerts", func(r chi.Router) {
			r.Get("/", handlers.GetRevoked(PFPki))
			r.Post("/search", handlers.SearchRevoked(PFPki))
		})
		// Revoke certs api endpoint
		r.Route("/pki/revokedcert", func(r chi.Router) {
			r.Get("/{id}", handlers.GetRevokedByID(PFPki))
		})
		// Check renewal api endpoint
		r.Get("/pki/checkrenewal", handlers.CheckRenewal(PFPki))
		// OCSP api endpoint
		r.Route("/pki/ocsp", func(r chi.Router) {
			r.Get("/", handlers.ManageOcsp(PFPki))
			r.Post("/", handlers.ManageOcsp(PFPki))
		})
		// SCEP api endpoint
		r.Route("/pki/scep", func(r chi.Router) {
			r.Get("/", handlers.ManageSCEP(PFPki))
			r.Post("/", handlers.ManageSCEP(PFPki))
			r.Get("/{id}", handlers.ManageSCEP(PFPki))
			r.Post("/{id}", handlers.ManageSCEP(PFPki))
			r.Get("/{id}/pkiclient.exe", handlers.ManageSCEP(PFPki))
			r.Post("/{id}/pkiclient.exe", handlers.ManageSCEP(PFPki))
			r.Get("/{id}/", handlers.ManageSCEP(PFPki))
			r.Post("/{id}/", handlers.ManageSCEP(PFPki))
		})
		r.Route("/scep", func(r chi.Router) {
			r.Get("/", handlers.ManageSCEP(PFPki))
			r.Post("/", handlers.ManageSCEP(PFPki))
			r.Get("/{id}", handlers.ManageSCEP(PFPki))
			r.Post("/{id}", handlers.ManageSCEP(PFPki))
			r.Get("/{id}/pkiclient.exe", handlers.ManageSCEP(PFPki))
			r.Post("/{id}/pkiclient.exe", handlers.ManageSCEP(PFPki))
		})
		// SCEPServers api endpoint
		r.Route("/pki/scepservers", func(r chi.Router) {
			r.Get("/", handlers.GetSetSCEPServer(PFPki))
			r.Post("/", handlers.GetSetSCEPServer(PFPki))
			r.Post("/search", handlers.SearchSCEPServer(PFPki))
		})
		r.Route("/pki/scepserver", func(r chi.Router) {
			r.Get("/{id}", handlers.SCEPServerByID(PFPki))
			r.Patch("/{id}", handlers.SCEPServerByID(PFPki))
			r.Delete("/{id}", handlers.SCEPServerByID(PFPki))
		})

	})

	pfpki.Router = r

	go func() {
		ticker := time.NewTicker(5 * time.Second)
		for {
			select {
			case <-ticker.C:
				sqlDB, _ := pfpki.DB.DB()
				sqlDB.Ping()
			case <-h.cancelCtx.Done():
				return
			}
		}
	}()

	h.Handler = pfpki
	return nil
}

func (s *Handler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	return h.Handler.ServeHTTP(w, r, next)
}

func (h *Handler) Validate() error {
	return nil
}

func (h *Handler) Cleanup() error {
	h.cancel()
	return nil
}

var (
	_ caddy.Provisioner           = (*Handler)(nil)
	_ caddy.CleanerUpper          = (*Handler)(nil)
	_ caddy.Validator             = (*Handler)(nil)
	_ caddyhttp.MiddlewareHandler = (*Handler)(nil)
	_ caddyfile.Unmarshaler       = (*Handler)(nil)
)
