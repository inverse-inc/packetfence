package api

import (
	"context"
	"net/http"
	"sync"
	"time"

	"database/sql"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/db/sqlcomment"
	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(APIHandler{})
	httpcaddyfile.RegisterHandlerDirective("api", utils.ParseCaddyfile[APIHandler])
}

// CaddyModule returns the Caddy module information.
func (APIHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.api",
		New: func() caddy.Module {
			return &APIHandler{}
		},
	}
}

type APIHandler struct {
	router *chi.Mux
	ctx    context.Context
}

// Setup the api middleware
// Also loads the pfconfig resources and registers them in the pool
func (m *APIHandler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())

	err := m.buildHandler(ctx)

	if err != nil {
		return err
	}

	setupRadiusDictionary()

	pfconfigdriver.AddRefreshable(ctx, "fbcollectorclient", fbcollectorclient.FromConfig(ctx))

	return nil
}

// Build the Handler which will initialize the routes
func (m *APIHandler) buildHandler(ctx context.Context) error {
	m.ctx = ctx
	router := chi.NewRouter()
	m.router = router

	m.router.Use(middleware.RequestID)
	m.router.Use(middleware.RealIP)
	m.router.Use(middleware.Logger)
	m.router.Use(middleware.Recoverer)

	m.router.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Wrap the response writer to preserve interfaces
			fw := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			next.ServeHTTP(fw, r)
		})
	})

	m.router.Route("/api/v1", func(r chi.Router) {
		r.Post("/radius_attributes", m.searchRadiusAttributes())
		r.Post("/nodes/fingerbank_communications", m.nodeFingerbankCommunications())
		r.Route("/ntlm", func(r chi.Router) {
			r.Post("/test", m.ntlmTest())
			r.Post("/event-report", m.eventReport())
		})
		r.Route("/fleetdm-events", func(r chi.Router) {
			r.Post("/policy", m.Policy())
			r.Post("/cve", m.CVE())
		})
		r.Get("/elasticsearch", m.handleElasticsearch())
	})

	var DBP **gorm.DB
	var DB *gorm.DB
	var sqlDB *sql.DB
	var err error
	done := false
	wait := false

	wg := &sync.WaitGroup{}
	wg.Add(1)

	go func() {
		for {
			if done == false {
				DB, err = gorm.Open(mysql.New(mysql.Config{DriverName: sqlcomment.DriverName, DSN: db.ReturnURIFromConfig(ctx)}), &gorm.Config{})
				if DB != nil {
					DBP = &DB
					if wait == false {
						wait = true
						wg.Done()
					}
				}

				if DB == nil {
					log.LoggerWContext(ctx).Warn("gorm db is nil while trying to open db")
				}
				if err != nil {
					log.LoggerWContext(ctx).Warn(err.Error())
				}
				if DB != nil && err == nil {
					sqlDB, err = DB.DB()
					err := sqlDB.Ping()
					if err == nil {
						done = true
					} else {
						log.LoggerWContext(ctx).Warn(err.Error())
						err := sqlDB.Close()
						if err != nil {
							log.LoggerWContext(ctx).Warn("error occured while closing db: ", err.Error())
						}
					}
				}
				time.Sleep(time.Duration(10) * time.Second)
			} else {
				sqlDB, err = DB.DB()
				err := sqlDB.Ping()
				if err != nil {
					done = false
					log.LoggerWContext(ctx).Warn(err.Error())
					err := sqlDB.Close()
					if err != nil {
						log.LoggerWContext(ctx).Warn("error occured while closing db: ", err.Error())
					}
				}
				time.Sleep(time.Duration(5) * time.Second)
			}
		}
	}()

	wg.Wait()
	NewAdminApiAuditLog(ctx, DBP).AddToRouter(router)
	NewAuthLog(ctx, DBP).AddToRouter(router)
	NewDnsAuditLog(ctx, DBP).AddToRouter(router)
	NewRadacctLog(ctx, DBP).AddToRouter(router)
	NewRadiusAuditLog(ctx, DBP).AddToRouter(router)
	NewWrix(ctx, DBP).AddToRouter(router)
	NewDynamicReport(ctx, DBP).AddToRouter(router)

	m.router = router
	return nil
}

func (h *APIHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	// Searches and options of non sql reports are proxied to the perl API
	if rewriteNonSqlReportRequest(r) {
		return next.ServeHTTP(w, r)
	}

	routeContext := chi.NewRouteContext()
	if h.router.Match(routeContext, r.Method, r.URL.Path) {
		// We always default to application/json
		w.Header().Set("Content-Type", "application/json")
		h.router.ServeHTTP(w, r)
		return nil
	}

	return next.ServeHTTP(w, r)
}

func (p *APIHandler) Validate() error {
	return nil
}

func (p *APIHandler) Cleanup() error {
	return nil
}

func (s *APIHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

var (
	_ caddy.Provisioner           = (*APIHandler)(nil)
	_ caddy.CleanerUpper          = (*APIHandler)(nil)
	_ caddy.Validator             = (*APIHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*APIHandler)(nil)
	_ caddyfile.Unmarshaler       = (*APIHandler)(nil)
)
