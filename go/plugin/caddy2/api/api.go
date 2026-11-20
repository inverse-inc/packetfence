package api

import (
	"context"
	"net/http"
	"sync"

	"database/sql"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/inverse-inc/packetfence/go/uiplugins"
	"github.com/julienschmidt/httprouter"
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
	router *httprouter.Router
	// db overrides the shared pool (tests only); nil means resolve it per use
	// via sqlDB(). Only through sqlDB and setSQLDB (guarded by sqlDBLock).
	db *sql.DB
}

// guards APIHandler.db. A package lock and not a field: CaddyModule has a
// value receiver, APIHandler must stay copyable.
var sqlDBLock sync.RWMutex

func (m *APIHandler) setSQLDB(database *sql.DB) {
	sqlDBLock.Lock()
	defer sqlDBLock.Unlock()
	m.db = database
}

// pluginDB is the raw SQL handle for the UI plugins, nil when the database
// cannot be opened. It is resolved on each use (a cached lookup in the shared
// pool cache, which also keeps concurrent requests from opening it twice), so
// a failure at startup is retried by the next request.
func (m *APIHandler) pluginDB(ctx context.Context) *sql.DB {
	database, err := m.sqlDB(ctx)
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to open the database for the UI plugins: " + err.Error())
		return nil
	}
	return database
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
	router := httprouter.New()
	m.router = router

	router.POST("/api/v1/radius_attributes", m.searchRadiusAttributes)

	router.POST("/api/v1/nodes/fingerbank_communications", m.nodeFingerbankCommunications)

	router.POST("/api/v1/ntlm/test", m.ntlmTest)
	router.POST("/api/v1/ntlm/event-report", m.eventReport)

	router.POST("/api/v1/fleetdm-events/policy", m.Policy)
	router.POST("/api/v1/fleetdm-events/cve", m.CVE)
	router.GET("/api/v1/elasticsearch", m.handleElasticsearch)

	router.GET("/api/v1/plugins", m.plugins)
	router.GET("/api/v1/plugins/:name/bundle.js", m.pluginBundle)
	for _, method := range uiplugins.ProxyMethods {
		router.Handle(method, "/api/v1/plugin/:name/*path", m.pluginProxy)
	}

	// Nothing here touches the database: provisioning must not wait for it,
	// or an outage at startup keeps every route of this server down. The DAL
	// routes resolve the shared GORM handle per request (a cached lookup once
	// opened) and answer 503 while the database is unreachable.
	NewAdminApiAuditLog(ctx, gormFromConfig).AddToRouter(router)
	NewAuthLog(ctx, gormFromConfig).AddToRouter(router)
	NewDnsAuditLog(ctx, gormFromConfig).AddToRouter(router)
	NewRadacctLog(ctx, gormFromConfig).AddToRouter(router)
	NewRadiusAuditLog(ctx, gormFromConfig).AddToRouter(router)
	NewWrix(ctx, gormFromConfig).AddToRouter(router)
	NewDynamicReport(ctx, gormFromConfig).AddToRouter(router)

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

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		// We always default to application/json
		w.Header().Set("Content-Type", "application/json")
		handle(w, r, params)
		return nil
	} else {
		return next.ServeHTTP(w, r)
	}

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
