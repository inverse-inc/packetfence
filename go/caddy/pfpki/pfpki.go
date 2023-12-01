package pfpki

import (
	"context"
	"fmt"
	"net/http"
	"time"

	chi "github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/handlers"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/models"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/inverse-inc/packetfence/go/db"
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

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

	// pfpki.DB.AutoMigrate(&models.Profile{})
	// pfpki.DB.AutoMigrate(&models.CA{})
	// pfpki.DB.AutoMigrate(&models.Cert{})
	// pfpki.DB.AutoMigrate(&models.RevokedCert{})
	// pfpki.DB.AutoMigrate(&models.SCEPServer{})

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	PFPki := &pfpki

	r.Route("/api/v1", func(r chi.Router) {
		r.Route("/pki/cas", func(r chi.Router) {
			r.Get("/", handlers.GetSetCA(PFPki))
			r.Post("/", handlers.GetSetCA(PFPki))
			r.Post("/search", handlers.SearchCA(PFPki))
		})

		r.Route("/pki/ca", func(r chi.Router) {
			r.Get("/fix", handlers.FixCA(PFPki))
			r.Get("/{id}", handlers.CAByID(PFPki))
			r.Patch("/{id}", handlers.CAByID(PFPki))
			r.Post("/resign/{id}", handlers.ResignCA(PFPki))
			r.Post("/csr/{id}", handlers.GenerateCSR(PFPki))
		})

		r.Route("/pki/profiles", func(r chi.Router) {
			r.Post("/", handlers.GetSetProfile(PFPki))
			r.Get("/", handlers.GetSetProfile(PFPki))
			r.Post("/search", handlers.SearchProfile(PFPki))
		})
		r.Route("/pki/profile", func(r chi.Router) {
			r.Patch("/{id}", handlers.GetProfileByID(PFPki))
			r.Get("/{id}", handlers.GetProfileByID(PFPki))
			r.Post("/{id}/sign_csr", handlers.SignCSR(PFPki))

		})
		r.Route("/pki/certs", func(r chi.Router) {
			r.Post("/", handlers.GetSetCert(PFPki))
			r.Get("/", handlers.GetSetCert(PFPki))
			r.Post("/search", handlers.SearchCert(PFPki))
		})

		r.Route("/pki/cert", func(r chi.Router) {
			r.Get("/{id}", handlers.GetCertByID(PFPki))
			r.Get("/{id}/download/{password}", handlers.DownloadCert(PFPki))
			r.Get("/{profile}/{id}/download/{password}", handlers.DownloadCert(PFPki))
			r.Get("/{id}/email", handlers.EmailCert(PFPki))
			r.Delete("/{id}/{reason}", handlers.RevokeCert(PFPki))
			r.Post("/resign/{id}", handlers.ResignCert(PFPki))
			r.Delete("/{profile}/{cn}/{reason}", handlers.RevokeCert(PFPki))
		})
		r.Route("/pki/revokedcerts", func(r chi.Router) {
			r.Get("/", handlers.GetRevoked(PFPki))
			r.Post("/search", handlers.SearchRevoked(PFPki))
		})

		r.Route("/pki/revokedcert", func(r chi.Router) {
			r.Get("/{id}", handlers.GetRevokedByID(PFPki))
		})

		r.Get("/pki/checkrenewal", handlers.CheckRenewal(PFPki))

		r.Route("/pki/scepservers", func(r chi.Router) {
			r.Get("/", handlers.GetSetSCEPServer(PFPki))
			r.Post("/", handlers.GetSetSCEPServer(PFPki))
			r.Post("/search", handlers.SearchSCEPServer(PFPki))
			r.Get("/{id}", handlers.SCEPServerByID(PFPki))
			r.Patch("/{id}", handlers.SCEPServerByID(PFPki))
		})

		// OCSP routes
		r.Route("/pki/ocsp", func(r chi.Router) {
			r.Get("/ocsp", handlers.ManageOcsp(PFPki))
			r.Post("/ocsp", handlers.ManageOcsp(PFPki))
		})

		//SCEP routes
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

		// EST routes
		r.Route("/est", func(r chi.Router) {
			r.Get("/{id}", handlers.ManageEST(PFPki))
			r.Post("/{id}", handlers.ManageEST(PFPki))
		})

		r.Route("/pki/est", func(r chi.Router) {
			r.Get("/{id}", handlers.ManageEST(PFPki))
			r.Post("/{id}", handlers.ManageEST(PFPki))
		})
		r.Route("/.well-known", func(r chi.Router) {
			r.Get("/{id}", handlers.ManageEST(PFPki))
			r.Post("/{id}", handlers.ManageEST(PFPki))
			r.Get("/*", handlers.ManageEST(PFPki))
			r.Post("/*", handlers.ManageEST(PFPki))
		})
	})

	pfpki.Router = r

	go func() {
		for {

			sqlDB, _ := pfpki.DB.DB()
			sqlDB.Ping()
			time.Sleep(5 * time.Second)
		}
	}()

	return pfpki, nil
}
