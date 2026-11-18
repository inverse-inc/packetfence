package api

// The admin UI plugins, see the Developers Guide, "Admin UI plugins":
//
//	GET /api/v1/plugins                the plugins whose manifest is reachable and valid
//	GET /api/v1/plugins/<name>/bundle.js  the code of a bundle plugin, from its package (go/uiplugins BundleCode)
//	*   /api/v1/plugin/<name>/<path>   the declared API, proxied to <scheme>://<host>:<port>/<path> (go/uiplugins Proxy)
//
// The plugins register themselves in the ui_plugin table (go/uiplugins,
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
	"github.com/inverse-inc/packetfence/go/api-frontend/aaa"
	"github.com/inverse-inc/packetfence/go/config/pfcrypt"
	"github.com/inverse-inc/packetfence/go/uiplugins"
	"github.com/julienschmidt/httprouter"
	"golang.org/x/sync/singleflight"
)

var pluginsFetcher = uiplugins.NewFetcher(func(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Warn(msg)
})

func init() {
	// the key of the signature of the requests to the plugins
	uiplugins.SystemInitKey = pfcrypt.SystemInitKey
}

// how long the read-only state of the database is reused, as pf::db
// db_check_readonly does
const pluginReadOnlyTTL = 5 * time.Second

type pluginReadOnlyCache struct {
	lock     sync.Mutex
	readOnly bool
	known    bool
	expires  time.Time
	// one query at a time, never under lock
	query singleflight.Group
}

var pluginReadOnly = &pluginReadOnlyCache{}

// get tells if the database is read-only, as pf::db db_readonly_mode: the
// read_only flag is set, or a Galera node is not ready (wsrep_ready is not ON
// while there is a wsrep provider). A database that cannot be read is not
// read-only: the plugin call fails on its own.
//
// The lock is not held during the query. Once the state is known, an expired
// one is still answered while a single query refreshes it in the background;
// the first requests wait for that single query.
func (c *pluginReadOnlyCache) get(ctx context.Context, database func(context.Context) *sql.DB) bool {
	c.lock.Lock()
	readOnly, known, fresh := c.readOnly, c.known, time.Now().Before(c.expires)
	c.lock.Unlock()
	if known && fresh {
		return readOnly
	}
	refresh := c.query.DoChan("read-only", func() (any, error) {
		qctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), pluginRegistrationsTimeout)
		defer cancel()
		readOnly := databaseReadOnly(qctx, database(qctx))
		c.lock.Lock()
		c.readOnly, c.known, c.expires = readOnly, true, time.Now().Add(pluginReadOnlyTTL)
		c.lock.Unlock()
		return readOnly, nil
	})
	if known {
		return readOnly
	}
	select {
	case result := <-refresh:
		return result.Val.(bool)
	case <-ctx.Done():
		return false
	}
}

// databaseReadOnly is the query of pluginReadOnlyCache, a variable for the tests
var databaseReadOnly = func(ctx context.Context, database *sql.DB) bool {
	if database == nil {
		return false
	}
	var readOnly int
	if err := database.QueryRowContext(ctx, "SELECT @@global.read_only").Scan(&readOnly); err != nil {
		return false
	}
	if readOnly != 0 {
		return true
	}
	var name, provider string
	if err := database.QueryRowContext(ctx, "SHOW STATUS LIKE 'wsrep_provider_name'").Scan(&name, &provider); err != nil || provider == "" {
		return false
	}
	// a node with a wsrep provider that cannot tell it is ready is read-only,
	// as pf::db db_wsrep_healthy
	var ready string
	if err := database.QueryRowContext(ctx, "SHOW STATUS LIKE 'wsrep_ready'").Scan(&name, &ready); err != nil {
		return true
	}
	return ready != "ON"
}

// how long the registrations read from the database are reused, also after a
// failed read (negative caching: a hung database is queried at most once per
// TTL, not by every request)
const pluginRegistrationsTTL = 5 * time.Second

type pluginRegistrationsCache struct {
	lock          sync.Mutex
	registrations map[string]uiplugins.Registration
	// the error of the last read when there are no previous registrations
	err     error
	expires time.Time
	// the reads in flight: concurrent requests share one query
	group singleflight.Group
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
// pluginRegistrationsTTL. The query runs outside the lock and is shared by
// the concurrent requests (singleflight); it is bounded by
// pluginRegistrationsTimeout and does not depend on the request that started
// it. When it fails the last registrations are used until the next TTL.
func (c *pluginRegistrationsCache) get(ctx context.Context, database func(context.Context) *sql.DB) (map[string]uiplugins.Registration, error) {
	if registrations, err, fresh := c.cached(); fresh {
		return registrations, err
	}
	v, err, _ := c.group.Do("registrations", func() (any, error) {
		// another request may have refreshed while this one waited
		if registrations, err, fresh := c.cached(); fresh {
			return registrations, err
		}
		qctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), pluginRegistrationsTimeout)
		defer cancel()
		registrations, err := listPluginRegistrations(qctx, database(qctx))
		c.lock.Lock()
		defer c.lock.Unlock()
		c.expires = time.Now().Add(pluginRegistrationsTTL)
		if err != nil {
			if c.registrations != nil {
				log.LoggerWContext(ctx).Warn("Unable to read the UI plugins registrations, using the previous ones: " + err.Error())
				return c.registrations, nil
			}
			c.err = err
			return nil, err
		}
		c.registrations, c.err = registrations, nil
		return registrations, nil
	})
	if err != nil {
		return nil, err
	}
	return v.(map[string]uiplugins.Registration), nil
}

// the cached answer, fresh is false when the TTL is over
func (c *pluginRegistrationsCache) cached() (registrations map[string]uiplugins.Registration, err error, fresh bool) {
	c.lock.Lock()
	defer c.lock.Unlock()
	if !time.Now().Before(c.expires) || (c.registrations == nil && c.err == nil) {
		return nil, nil, false
	}
	if c.registrations != nil {
		return c.registrations, nil, true
	}
	return nil, c.err, true
}

func (c *pluginRegistrationsCache) reset() {
	c.lock.Lock()
	defer c.lock.Unlock()
	c.registrations, c.err = nil, nil
	c.expires = time.Time{}
}

// GET /api/v1/plugins: the plugins whose menu.can the admin satisfies
func (h *APIHandler) plugins(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	plugins := []uiplugins.Plugin{}
	registrations, err := pluginRegistrations.get(ctx, h.pluginDB)
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

// GET /api/v1/plugins/<name>/bundle.js: the code of a bundle plugin the
// admin may use (menu.can), as its package installed it. The admin UI loads
// it with the admin token, then imports it.
func (h *APIHandler) pluginBundle(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	w.Header().Del("Content-Type")
	name := p.ByName("name")
	registrations, err := pluginRegistrations.get(ctx, h.pluginDB)
	if err != nil {
		uiplugins.Error(w, http.StatusServiceUnavailable, "Unable to load the plugins")
		return
	}
	registration, found := registrations[name]
	if !found {
		uiplugins.Error(w, http.StatusNotFound, fmt.Sprintf("No plugin %q", name))
		return
	}
	manifest := pluginsFetcher.Manifest(ctx, registration)
	if manifest == nil || !manifest.IsBundle() {
		uiplugins.Error(w, http.StatusNotFound, fmt.Sprintf("No bundle for the plugin %q", name))
		return
	}
	if !manifest.Menu.Can.Allowed(pluginAdminActions(ctx, uiplugins.AdminRoles(r))) {
		uiplugins.Error(w, http.StatusForbidden, fmt.Sprintf("Plugin %q: the admin roles do not satisfy menu.can", name))
		return
	}
	code, err := uiplugins.BundleCode(name)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("UI plugin %q: bundle refused: %s", name, err))
		uiplugins.Error(w, http.StatusNotFound, fmt.Sprintf("No bundle for the plugin %q", name))
		return
	}
	w.Header().Set("Content-Type", "text/javascript; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Cache-Control", "no-store")
	w.Write(code)
}

// * /api/v1/plugin/<name>/<path>
func (h *APIHandler) pluginProxy(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	// ServeHTTP set a default, the plugin answer sets its own
	w.Header().Del("Content-Type")
	name := p.ByName("name")
	registrations, err := pluginRegistrations.get(ctx, h.pluginDB)
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
	// the path as the admin sent it, not decoded: an item id can hold a "/"
	path, ok := uiplugins.ProxyPath(r, name)
	if !ok {
		uiplugins.Error(w, http.StatusNotFound, fmt.Sprintf("No plugin %q", name))
		return
	}
	identity := uiplugins.IdentityOf(r, pluginAdminActions(ctx, uiplugins.AdminRoles(r)))
	pluginsFetcher.Proxy(w, r, registration, path, identity, func(ctx context.Context) bool {
		return pluginReadOnly.get(ctx, h.pluginDB)
	})
}

// the actions of admin roles, as api-aaa computes them, a variable for the
// tests
var pluginAdminActions = aaa.ActionsForRoles
