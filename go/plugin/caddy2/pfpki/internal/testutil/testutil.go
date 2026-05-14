// Package testutil provides shared helpers for pfpki tests: an in-memory
// SQLite DB seeded with the model schema, a *types.Handler bound to that DB,
// and an httptest.Server fronting the chi router used by the production
// caddy plugin.
//
// The route table is kept in sync with pfpki.buildPfpkiHandler by hand. If
// you add a route there, mirror it in NewServer.
package testutil

import (
	"context"
	"net/http/httptest"
	"testing"

	chi "github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/handlers"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Env bundles every piece a pfpki test typically needs.
type Env struct {
	DB      *gorm.DB
	Ctx     context.Context
	Handler *types.Handler
	Server  *httptest.Server
}

// NewEnv opens an in-memory SQLite database, runs AutoMigrate over every
// model the pfpki package persists, wires a *types.Handler and a chi router,
// and starts an httptest.Server. Everything is torn down via t.Cleanup.
func NewEnv(t *testing.T) *Env {
	t.Helper()

	// shared cache lets multiple gorm sessions on the same in-memory DB see
	// each other; without it each connection gets its own fresh database.
	// _loc=auto + parseTime=true make the sqlite3 driver hand back time.Time
	// values for datetime/time columns instead of raw strings.
	db, err := gorm.Open(sqlite.Open("file::memory:?cache=shared&_loc=auto&parseTime=true"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}

	// Create tables one by one. SQLite keeps indexes in a single global
	// namespace, while the production models reuse short index names
	// ("mail", "organisation", "ca_id", …) across several tables — fine on
	// MySQL, fatal on SQLite. We use Migrator.CreateTable (no automatic
	// dependency reorder, unlike AutoMigrate) and drop the named indexes
	// between calls so each table can claim them in turn. The dropped
	// indexes don't matter for unit-test correctness, only for query plans
	// on this throwaway in-memory DB.
	sharedIndexNames := []string{
		"mail", "organisation", "ca_id", "ca_name",
		"profile_id", "profile_name", "valid_until",
		"not_before", "revoked", "crl_reason",
		"scep_server_id", "cn",
	}
	migrate := func(m interface{}) {
		if err := db.Migrator().CreateTable(m); err != nil {
			// CreateTable runs CREATE TABLE then CREATE INDEX; the table is
			// already in place even when an index step trips on a global
			// SQLite name collision.
			t.Logf("CreateTable %T (ignored): %v", m, err)
		}
		for _, idx := range sharedIndexNames {
			db.Exec("DROP INDEX IF EXISTS " + idx)
		}
	}
	for _, m := range []interface{}{
		&models.CA{},
		&models.Profile{},
		&models.Cert{},
		&models.RevokedCert{},
		&models.SCEPServer{},
		&admin_api_audit_log.AdminApiAuditLog{},
	} {
		migrate(m)
	}

	ctx := context.Background()
	h := &types.Handler{DB: db, Ctx: &ctx}

	// Profile.New requires a SCEPServer row at id=1 (the default). Seed it.
	if err := db.Create(&models.SCEPServer{Name: "default", URL: "http://localhost", SharedSecret: "secret"}).Error; err != nil {
		t.Fatalf("seed default SCEPServer: %v", err)
	}

	router := newRouter(h)
	srv := httptest.NewServer(router)

	t.Cleanup(func() {
		srv.Close()
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})

	return &Env{DB: db, Ctx: ctx, Handler: h, Server: srv}
}

// newRouter mirrors pfpki.buildPfpkiHandler's chi setup, minus the DB
// ticker. Keep in sync with that file when routes change.
func newRouter(h *types.Handler) chi.Router {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.Recoverer)
	r.Use(handlers.LimitRequestBody)

	r.Route("/api/v1", func(r chi.Router) {
		r.Route("/pki/cas", func(r chi.Router) {
			r.Get("/", handlers.GetSetCA(h))
			r.Post("/", handlers.GetSetCA(h))
			r.Post("/search", handlers.SearchCA(h))
		})
		r.Route("/pki/ca", func(r chi.Router) {
			r.Get("/fix", handlers.FixCA(h))
			r.Get("/{id}", handlers.CAByID(h))
			r.Patch("/{id}", handlers.CAByID(h))
			r.Post("/resign/{id}", handlers.ResignCA(h))
			r.Post("/csr/{id}", handlers.GenerateCSR(h))
		})
		r.Route("/pki/profiles", func(r chi.Router) {
			r.Post("/", handlers.GetSetProfile(h))
			r.Get("/", handlers.GetSetProfile(h))
			r.Post("/search", handlers.SearchProfile(h))
		})
		r.Route("/pki/profile", func(r chi.Router) {
			r.Patch("/{id}", handlers.GetProfileByID(h))
			r.Get("/{id}", handlers.GetProfileByID(h))
			r.Post("/{id}/sign_csr", handlers.SignCSR(h))
		})
		r.Route("/pki/certs", func(r chi.Router) {
			r.Post("/", handlers.GetSetCert(h))
			r.Get("/", handlers.GetSetCert(h))
			r.Post("/search", handlers.SearchCert(h))
		})
		r.Route("/pki/cert", func(r chi.Router) {
			r.Get("/{id}", handlers.GetCertByID(h))
			r.Get("/{id}/download/{password}", handlers.DownloadCert(h))
			r.Get("/{profile}/{id}/download/{password}", handlers.DownloadCert(h))
			r.Get("/{id}/email", handlers.EmailCert(h))
			r.Delete("/{id}/{reason}", handlers.RevokeCert(h))
			r.Post("/resign/{id}", handlers.ResignCert(h))
			r.Delete("/{profile}/{cn}/{reason}", handlers.RevokeCert(h))
		})
		r.Route("/pki/revokedcerts", func(r chi.Router) {
			r.Get("/", handlers.GetRevoked(h))
			r.Post("/search", handlers.SearchRevoked(h))
		})
		r.Route("/pki/revokedcert", func(r chi.Router) {
			r.Get("/{id}", handlers.GetRevokedByID(h))
		})
		r.Get("/pki/checkrenewal", handlers.CheckRenewal(h))
		r.Get("/pki/process_cloud_revocations", handlers.ProcessCloudRevocations(h))
		r.Post("/pki/process_cloud_revocations", handlers.ProcessCloudRevocations(h))
		r.Route("/pki/ocsp", func(r chi.Router) {
			r.Get("/", handlers.ManageOcsp(h))
			r.Post("/", handlers.ManageOcsp(h))
		})
		r.Route("/pki/scep", func(r chi.Router) {
			r.Get("/", handlers.ManageSCEP(h))
			r.Post("/", handlers.ManageSCEP(h))
			r.Get("/{id}", handlers.ManageSCEP(h))
			r.Post("/{id}", handlers.ManageSCEP(h))
			r.Get("/{id}/pkiclient.exe", handlers.ManageSCEP(h))
			r.Post("/{id}/pkiclient.exe", handlers.ManageSCEP(h))
		})
		r.Route("/pki/scepservers", func(r chi.Router) {
			r.Get("/", handlers.GetSetSCEPServer(h))
			r.Post("/", handlers.GetSetSCEPServer(h))
			r.Post("/search", handlers.SearchSCEPServer(h))
		})
		r.Route("/pki/scepserver", func(r chi.Router) {
			r.Get("/{id}", handlers.SCEPServerByID(h))
			r.Patch("/{id}", handlers.SCEPServerByID(h))
			r.Delete("/{id}", handlers.SCEPServerByID(h))
		})
	})

	return r
}
