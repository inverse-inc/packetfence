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
	"github.com/inverse-inc/packetfence/go/uiplugins"
	"golang.org/x/sync/singleflight"
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
	// the raw SQL handle, only through sqlDB, setSQLDB and pluginDB (guarded
	// by sqlDBLock)
	db *sql.DB
}

// guards APIHandler.db: written at startup and by a lazy reopen, read by the
// request handlers. A package lock and not a field: CaddyModule has a value
// receiver, APIHandler must stay copyable.
var sqlDBLock sync.RWMutex

// sqlDB is the raw SQL handle, nil when it could not be opened
func (m *APIHandler) sqlDB() *sql.DB {
	sqlDBLock.RLock()
	defer sqlDBLock.RUnlock()
	return m.db
}

func (m *APIHandler) setSQLDB(database *sql.DB) {
	sqlDBLock.Lock()
	defer sqlDBLock.Unlock()
	m.db = database
}

// opens the raw SQL handle, a variable for the tests
var openPluginDB = db.DbFromConfig

// one open of the raw SQL handle at a time, for the concurrent requests
var pluginDBOpen singleflight.Group

// pluginDB is the raw SQL handle, opened again when it could not be at
// startup. Opening it creates the pool without connecting (sql.Open): the
// singleflight only keeps the concurrent requests from creating a pool each,
// all but one then left open. It is done without holding sqlDBLock, which
// the other handlers read the handle with.
func (m *APIHandler) pluginDB(ctx context.Context) *sql.DB {
	if database := m.sqlDB(); database != nil {
		return database
	}
	opened, _, _ := pluginDBOpen.Do("open", func() (any, error) {
		if database := m.sqlDB(); database != nil {
			return database, nil
		}
		database, err := openPluginDB(context.WithoutCancel(ctx))
		if err != nil {
			log.LoggerWContext(ctx).Error("Unable to open the database for the UI plugins: " + err.Error())
			return nil, err
		}
		m.setSQLDB(database)
		return database, nil
	})
	if database, _ := opened.(*sql.DB); database != nil {
		return database
	}
	return m.sqlDB()
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
	router := chi.NewRouter()
	m.router = router

	// No RealIP/Logger: Caddy already writes the access log.
	m.router.Use(middleware.RequestID)
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
		r.Get("/plugins", m.plugins())
		r.Get("/plugins/{name}/bundle.js", m.pluginBundle())
		for _, method := range uiplugins.ProxyMethods {
			r.MethodFunc(method, "/plugin/{name}/*", m.pluginProxy())
		}
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
					if err != nil {
						log.LoggerWContext(ctx).Warn("Could not get the database handle: " + err.Error())
					} else {
						// gorm.Open builds its own *sql.DB, bypassing
						// db.ConnectURI, so the pool would otherwise run with Go's
						// defaults: unlimited connections that are never recycled.
						db.SetPoolLimits(sqlDB)
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
	// Standalone *sql.DB handle used by handlers that need raw SQL access (e.g. resolving
	// a node's connector from its locationlog switch IP).
	if sqlHandle, sqlErr := db.DbFromConfig(ctx); sqlErr != nil {
		log.LoggerWContext(ctx).Warn("Unable to open sql.DB handle for the API plugin: " + sqlErr.Error())
	} else {
		m.setSQLDB(sqlHandle)
	}
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

	// chi routes on RawPath when the URL has percent-encoded characters:
	// match on the same string, or an encoded path could match here and
	// then 404 inside the router instead of falling through to the Perl API.
	routePath := r.URL.RawPath
	if routePath == "" {
		routePath = r.URL.Path
	}
	routeContext := chi.NewRouteContext()
	if h.router.Match(routeContext, r.Method, routePath) {
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
