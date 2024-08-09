package pfsso

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/statsd"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/firewallsso"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/julienschmidt/httprouter"
	"github.com/patrickmn/go-cache"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(PfssoHandler{})
	httpcaddyfile.RegisterHandlerDirective("pfsso", utils.ParseCaddyfile[PfssoHandler])
}

// CaddyModule returns the Caddy module information.
func (PfssoHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.pfsso",
		New: func() caddy.Module {
			return &PfssoHandler{}
		},
	}
}

type PfssoHandler struct {
	router *httprouter.Router
	// The cache for the cached updates feature
	updateCache *cache.Cache
	connectors  *connector.ConnectorsContainer
}

// Setup the pfsso middleware
// Also loads the pfconfig resources and registers them in the pool
func (m *PfssoHandler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())

	err := m.buildPfssoHandler(ctx)

	if err != nil {
		return err
	}

	return nil
}

// Build the PfssoHandler which will initialize the cache and instantiate the router along with its routes
func (h *PfssoHandler) buildPfssoHandler(ctx context.Context) error {

	h.updateCache = cache.New(1*time.Hour, 30*time.Second)

	// Declare all pfconfig resources that will be necessary
	firewalls := firewallsso.NewFirewallsContainer(ctx)
	h.connectors = connector.NewConnectorsContainer(ctx)
	pfconfigdriver.AddType[pfconfigdriver.ManagementNetwork](ctx)
	pfconfigdriver.AddRefreshable(ctx, "firewallsso.FirewallsContainer", firewalls)

	router := httprouter.New()
	router.POST("/api/v1/firewall_sso/update", h.handleUpdate)
	router.POST("/api/v1/firewall_sso/start", h.handleStart)
	router.POST("/api/v1/firewall_sso/stop", h.handleStop)

	h.router = router

	return nil
}

// Parse the body of a pfsso request to extract a map[string]string of all the attributes that were sent
// Return an error if the JSON payload cannot be decoded properly
// Will also validate that the necessary fields are there in the payload and return an error if some are missing
func (h PfssoHandler) parseSsoRequest(ctx context.Context, r *http.Request) (map[string]string, int, error) {
	var info map[string]string
	err := json.NewDecoder(r.Body).Decode(&info)

	if err != nil {
		msg := fmt.Sprintf("Error while decoding payload: %s", err)
		log.LoggerWContext(ctx).Error(msg)
		return nil, 0, errors.New(msg)
	}

	timeout, err := strconv.ParseInt(info["timeout"], 10, 32)
	if err != nil {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Can't parse timeout '%s' into an int (%s). Will not specify timeout for request.", info["timeout"], err))
	}

	if err := h.validateInfo(ctx, info); err != nil {
		return nil, 0, err
	}

	if info["stripped_username"] == "" {
		log.LoggerWContext(ctx).Warn("No stripped_username set in the request, using the username as the stripped_username and no realm")
		info["stripped_username"] = info["username"]
	}

	return info, int(timeout), nil
}

// Validate that all the required fields are there in the request
func (h PfssoHandler) validateInfo(ctx context.Context, info map[string]string) error {
	required := []string{"ip", "mac", "username", "role"}
	for _, k := range required {
		if _, ok := info[k]; !ok {
			return errors.New(fmt.Sprintf("Missing %s in request", k))
		}
	}
	return nil
}

// Spawn an async SSO request for a specific firewall
func (h PfssoHandler) spawnSso(ctx context.Context, firewall firewallsso.FirewallSSOInt, info map[string]string, f func(ctx context.Context, info map[string]string) (bool, error)) {
	// Perform a copy of the information hash before spawning the goroutine
	infoCopy := map[string]string{}
	for k, v := range info {
		infoCopy[k] = v
	}

	go func() {
		defer panichandler.Standard(ctx)
		ctx = connector.WithConnectorsContainer(ctx, h.connectors)
		sent, err := f(ctx, infoCopy)
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while sending SSO to %s: %s"+firewall.GetFirewallSSO(ctx).PfconfigHashNS, err))
		}

		if sent {
			log.LoggerWContext(ctx).Debug("Sent SSO to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
		} else {
			log.LoggerWContext(ctx).Debug("Didn't send SSO to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
		}
	}()
}

// Add the info in the request to the log context
func (h PfssoHandler) addInfoToContext(ctx context.Context, info map[string]string) context.Context {
	return log.AddToLogContext(ctx, "username", info["username"], "ip", info["ip"], "mac", info["mac"], "role", info["role"])
}

// Handle an update action for pfsso
// If the firewall has cached updates enabled, it will handle it here
// The cache is in-memory so that means that a restart of the process will clear the cached updates cache
func (h PfssoHandler) handleUpdate(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleUpdate")

	info, timeout, err := h.parseSsoRequest(ctx, r)
	if err != nil {
		http.Error(w, fmt.Sprint(err), http.StatusBadRequest)
		return
	}

	ctx = h.addInfoToContext(ctx, info)
	firewalls := pfconfigdriver.GetRefresh(ctx, "firewallsso.FirewallsContainer").(*firewallsso.FirewallsContainer)

	var shouldStart bool
	for _, firewall := range firewalls.All(ctx) {
		cacheKey := firewall.GetFirewallSSO(ctx).PfconfigHashNS + "|mac|" + info["mac"] + "|ip|" + info["ip"] + "|username|" + info["username"] + "|role|" + info["role"]
		// Check whether or not this firewall has cache updates
		// Then check if an entry in the cache exists
		//  If it does exist, we don't send a Start
		//  Otherwise, we add an entry in the cache
		// Note that this has a race condition between the cache.Get and the cache.Set but it is acceptable since worst case will be that 2 SSO will be sent if both requests came in at that same nanosecond
		if firewall.ShouldCacheUpdates(ctx) {
			// Delete any entries for this MAC that aren't matching this cache key
			for k, _ := range h.updateCache.Items() {
				// If its not our current cache key but its made for the same MAC, then we'll remove it since its not relevant anymore
				if k != cacheKey && strings.Contains(k, "|mac|"+info["mac"]) {
					log.LoggerWContext(ctx).Debug("Deleting irrelevant cache key " + k)
					h.updateCache.Delete(k)
				}
			}

			if _, found := h.updateCache.Get(cacheKey); !found {

				var cacheTimeout int
				if firewall.GetFirewallSSO(ctx).GetCacheTimeout(ctx) != 0 {
					cacheTimeout = firewall.GetFirewallSSO(ctx).GetCacheTimeout(ctx)
				} else if timeout != 0 {
					cacheTimeout = timeout / 2
				} else {
					log.LoggerWContext(ctx).Error("Impossible to cache updates. There is no cache timeout in the firewall and no timeout defined in the request.")
				}

				if cacheTimeout != 0 {
					log.LoggerWContext(ctx).Debug(fmt.Sprintf("Caching SSO for %d seconds", cacheTimeout))
					h.updateCache.Set(cacheKey, 1, time.Duration(cacheTimeout)*time.Second)
				}

				shouldStart = true
			}
		} else {
			shouldStart = true
		}

		if shouldStart {
			//Creating a shallow copy here so the anonymous function has the right reference
			firewall := firewall
			h.spawnSso(ctx, firewall, info, func(ctx context.Context, info map[string]string) (bool, error) {
				return firewallsso.ExecuteStart(ctx, firewall, info, timeout)
			})
		} else {
			log.LoggerWContext(ctx).Debug("Determined that SSO start was not necessary for this update")
		}

	}

	w.WriteHeader(http.StatusAccepted)
}

// Handle an SSO start
func (h PfssoHandler) handleStart(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStart")

	info, timeout, err := h.parseSsoRequest(ctx, r)
	if err != nil {
		http.Error(w, fmt.Sprint(err), http.StatusBadRequest)
		return
	}

	ctx = h.addInfoToContext(ctx, info)
	firewalls := pfconfigdriver.GetRefresh(ctx, "firewallsso.FirewallsContainer").(*firewallsso.FirewallsContainer)

	for _, firewall := range firewalls.All(ctx) {
		//Creating a shallow copy here so the anonymous function has the right reference
		firewall := firewall
		h.spawnSso(ctx, firewall, info, func(ctx context.Context, info map[string]string) (bool, error) {
			return firewallsso.ExecuteStart(ctx, firewall, info, timeout)
		})
	}

	w.WriteHeader(http.StatusAccepted)
}

// Handle an SSO stop
func (h PfssoHandler) handleStop(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStop")

	info, _, err := h.parseSsoRequest(ctx, r)
	if err != nil {
		http.Error(w, fmt.Sprint(err), http.StatusBadRequest)
		return
	}

	ctx = h.addInfoToContext(ctx, info)

	// Delete any cache entries for this IP
	for k, _ := range h.updateCache.Items() {
		if strings.Contains(k, "|ip|"+info["ip"]+"|") {
			log.LoggerWContext(ctx).Debug("Deleting irrelevant cache key " + k)
			h.updateCache.Delete(k)
		}
	}
	firewalls := pfconfigdriver.GetRefresh(ctx, "firewallsso.FirewallsContainer").(*firewallsso.FirewallsContainer)

	for _, firewall := range firewalls.All(ctx) {
		//Creating a shallow copy here so the anonymous function has the right reference
		firewall := firewall
		h.spawnSso(ctx, firewall, info, func(ctx context.Context, info map[string]string) (bool, error) {
			return firewallsso.ExecuteStop(ctx, firewall, info)
		})
	}

	w.WriteHeader(http.StatusAccepted)
}

func (h *PfssoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)

		// TODO change me and wrap actions into something that handles server errors
		return nil
	}

	return next.ServeHTTP(w, r)
}

func (p *PfssoHandler) UnmarshalCaddyfile(d *caddyfile.Dispenser) error {
	return nil
}

func (p *PfssoHandler) Cleanup() error {
	return nil
}

func (p *PfssoHandler) Validate() error {
	return nil
}

var (
	_ caddy.Provisioner           = (*PfssoHandler)(nil)
	_ caddy.CleanerUpper          = (*PfssoHandler)(nil)
	_ caddy.Validator             = (*PfssoHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*PfssoHandler)(nil)
	_ caddyfile.Unmarshaler       = (*PfssoHandler)(nil)
)
