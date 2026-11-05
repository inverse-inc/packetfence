package api

// The admin UI plugins, see docs/ui-plugins/README.md:
//
//	GET /api/v1/plugins                the plugins whose manifest is reachable and valid
//	*   /api/v1/plugin/<name>/<path>   the declared API, proxied to <scheme>://<host>:<port>/<path> (go/uiplugins Proxy)
//
// The plugins register themselves in the chi_cache table (go/uiplugins,
// pf::ui_plugins).

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/uiplugins"
	"github.com/julienschmidt/httprouter"
)

var pluginsFetcher = uiplugins.NewFetcher(func(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Warn(msg)
})

// how long the registrations read from the database are reused
const pluginRegistrationsTTL = 5 * time.Second

type pluginRegistrationsCache struct {
	lock          sync.Mutex
	registrations map[string]uiplugins.Registration
	expires       time.Time
}

var pluginRegistrations = &pluginRegistrationsCache{}

// loads the registrations, a variable for the tests
var listPluginRegistrations = func(ctx context.Context, database *sql.DB) (map[string]uiplugins.Registration, error) {
	if database == nil {
		return nil, errors.New("no database handle")
	}
	return uiplugins.ListDB(ctx, database, func(err error) {
		log.LoggerWContext(ctx).Warn("UI plugin ignored: " + err.Error())
	})
}

// how long reading the registrations may take
const pluginRegistrationsTimeout = 3 * time.Second

// the registrations, read from the database at most every
// pluginRegistrationsTTL. The query is bounded by
// pluginRegistrationsTimeout; when it fails the last registrations are used.
func (c *pluginRegistrationsCache) get(ctx context.Context, database *sql.DB) (map[string]uiplugins.Registration, error) {
	c.lock.Lock()
	defer c.lock.Unlock()
	if c.registrations != nil && time.Now().Before(c.expires) {
		return c.registrations, nil
	}
	qctx, cancel := context.WithTimeout(ctx, pluginRegistrationsTimeout)
	defer cancel()
	registrations, err := listPluginRegistrations(qctx, database)
	if err != nil {
		if c.registrations != nil {
			log.LoggerWContext(ctx).Warn("Unable to read the UI plugins registrations, using the previous ones: " + err.Error())
			return c.registrations, nil
		}
		return nil, err
	}
	c.registrations, c.expires = registrations, time.Now().Add(pluginRegistrationsTTL)
	return registrations, nil
}

// the database handle, opened again when it could not be at startup
var pluginDBLock sync.Mutex

func (h *APIHandler) pluginDB(ctx context.Context) *sql.DB {
	pluginDBLock.Lock()
	defer pluginDBLock.Unlock()
	if h.db == nil {
		if database, err := db.DbFromConfig(ctx); err == nil {
			h.db = database
		} else {
			log.LoggerWContext(ctx).Error("Unable to open the database for the UI plugins: " + err.Error())
		}
	}
	return h.db
}

func (c *pluginRegistrationsCache) reset() {
	c.lock.Lock()
	defer c.lock.Unlock()
	c.registrations = nil
}

// GET /api/v1/plugins: the plugins whose menu.can the admin satisfies
func (h *APIHandler) plugins(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	plugins := []uiplugins.Plugin{}
	registrations, err := pluginRegistrations.get(ctx, h.pluginDB(ctx))
	if err != nil {
		// the admin UI must work without any plugin
		log.LoggerWContext(ctx).Error("Unable to load the UI plugins registrations: " + err.Error())
	} else {
		actions := pluginAdminActions(ctx, uiplugins.AdminRoles(r))
		for _, plugin := range pluginsFetcher.Plugins(ctx, registrations) {
			if plugin.Manifest.Menu.Can.Allowed(actions) {
				plugins = append(plugins, plugin)
			}
		}
	}
	json.NewEncoder(w).Encode(struct {
		Items  []uiplugins.Plugin `json:"items"`
		Status int                `json:"status"`
	}{Items: plugins, Status: http.StatusOK})
}

// * /api/v1/plugin/<name>/<path>
func (h *APIHandler) pluginProxy(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	// ServeHTTP set a default, the plugin answer sets its own
	w.Header().Del("Content-Type")
	name := p.ByName("name")
	registrations, err := pluginRegistrations.get(ctx, h.pluginDB(ctx))
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to load the UI plugins registrations: " + err.Error())
		uiplugins.Error(w, http.StatusServiceUnavailable, "Unable to load the plugins")
		return
	}
	registration, found := registrations[name]
	if !found {
		uiplugins.Error(w, http.StatusNotFound, fmt.Sprintf("No plugin %q", name))
		return
	}
	identity := uiplugins.IdentityOf(r, pluginAdminActions(ctx, uiplugins.AdminRoles(r)))
	pluginsFetcher.Proxy(w, r, registration, p.ByName("path"), identity)
}

// the actions of admin roles, a variable for the tests
var pluginAdminActions = adminActions

// the actions of admin roles, as api-aaa computes them (aaa.TokenInfo
// AdminActions)
func adminActions(ctx context.Context, roles []string) map[string]bool {
	adminRoles := pfconfigdriver.GetType[pfconfigdriver.AdminRoles](ctx)
	actions := map[string]bool{}
	for _, role := range roles {
		for action := range adminRoles.Element[role].Actions {
			actions[action] = true
		}
	}
	return actions
}
