package api

// The admin UI plugins, see docs/developer/ui_plugins.asciidoc:
//
//	GET /api/v1/plugins                the plugins whose manifest is reachable and valid
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
	"github.com/inverse-inc/packetfence/go/uiplugins"
	"github.com/julienschmidt/httprouter"
	"golang.org/x/sync/singleflight"
)

var pluginsFetcher = uiplugins.NewFetcher(func(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Warn(msg)
})

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
	pluginsFetcher.Proxy(w, r, registration, path, identity)
}

// the actions of admin roles, as api-aaa computes them, a variable for the
// tests
var pluginAdminActions = aaa.ActionsForRoles
