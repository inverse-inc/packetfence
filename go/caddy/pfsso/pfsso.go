package pfsso

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/firewallsso"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/statsd"
	"github.com/julienschmidt/httprouter"
	"github.com/patrickmn/go-cache"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("pfsso", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

type PfssoHandler struct {
	Next   httpserver.Handler
	router *httprouter.Router
	// The cache for the cached updates feature
	updateCache *cache.Cache
}

// Setup the pfsso middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfsso, err := buildPfssoHandler(ctx)

	if err != nil {
		return err
	}

	// Declare all pfconfig resources that will be necessary
	pfconfigdriver.PfconfigPool.AddRefreshable(ctx, &firewallsso.Firewalls)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.Interfaces.ManagementNetwork)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfsso.Next = next
		return pfsso
	})

	return nil
}

// Build the PfssoHandler which will initialize the cache and instantiate the router along with its routes
func buildPfssoHandler(ctx context.Context) (PfssoHandler, error) {

	pfsso := PfssoHandler{}

	pfsso.updateCache = cache.New(1*time.Hour, 30*time.Second)

	router := httprouter.New()
	router.POST("/api/v1/firewall_sso/update", pfsso.handleUpdate)
	router.POST("/api/v1/firewall_sso/start", pfsso.handleStart)
	router.POST("/api/v1/firewall_sso/stop", pfsso.handleStop)

	pfsso.router = router

	return pfsso, nil
}

// Parse the body of a pfsso request to extract a map[string]string of all the attributes that were sent
// Return an error if the JSON payload cannot be decoded properly
// Will also validate that the necessary fields are there in the payload and return an error if some are missing
func (h PfssoHandler) parseSsoRequest(ctx context.Context, body io.Reader) (map[string]string, int, error) {
	var info map[string]string
	err := json.NewDecoder(body).Decode(&info)

	if err != nil {
		msg := fmt.Sprintf("Error while decoding payload: %s", err)
		log.LoggerWContext(ctx).Error(msg)
		return nil, 0, errors.New(msg)
	}

	timeout, err := strconv.ParseInt(info["timeout"], 10, 32)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Can't parse timeout '%s' into an int (%s). Will not specify timeout for request.", info["timeout"], err))
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
func (h PfssoHandler) spawnSso(ctx context.Context, firewall firewallsso.FirewallSSOInt, info map[string]string, f func(info map[string]string) (bool, error)) {
	// Perform a copy of the information hash before spawning the goroutine
	infoCopy := map[string]string{}
	for k, v := range info {
		infoCopy[k] = v
	}

	go func() {
		defer panichandler.Standard(ctx)
		sent, err := f(infoCopy)
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

	info, timeout, err := h.parseSsoRequest(ctx, r.Body)
	if err != nil {
		http.Error(w, fmt.Sprint(err), http.StatusBadRequest)
		return
	}

	ctx = h.addInfoToContext(ctx, info)

	var shouldStart bool
	for _, firewall := range firewallsso.Firewalls.Structs {
		cacheKey := firewall.GetFirewallSSO(ctx).PfconfigHashNS + ":" + info["ip"]
		// Check whether or not this firewall has cache updates
		// Then check if an entry in the cache exists
		//  If it does exist, we don't send a Start
		//  Otherwise, we add an entry in the cache
		// Note that this has a race condition between the cache.Get and the cache.Set but it is acceptable since worst case will be that 2 SSO will be sent if both requests came in at that same nanosecond
		if firewall.ShouldCacheUpdates(ctx) {
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
			h.spawnSso(ctx, firewall, info, func(info map[string]string) (bool, error) {
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

	info, timeout, err := h.parseSsoRequest(ctx, r.Body)
	if err != nil {
		http.Error(w, fmt.Sprint(err), http.StatusBadRequest)
		return
	}

	ctx = h.addInfoToContext(ctx, info)

	for _, firewall := range firewallsso.Firewalls.Structs {
		//Creating a shallow copy here so the anonymous function has the right reference
		firewall := firewall
		h.spawnSso(ctx, firewall, info, func(info map[string]string) (bool, error) {
			return firewallsso.ExecuteStart(ctx, firewall, info, timeout)
		})
	}

	w.WriteHeader(http.StatusAccepted)
}

// Handle an SSO stop
func (h PfssoHandler) handleStop(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStop")

	info, _, err := h.parseSsoRequest(ctx, r.Body)
	if err != nil {
		http.Error(w, fmt.Sprint(err), http.StatusBadRequest)
		return
	}

	ctx = h.addInfoToContext(ctx, info)

	for _, firewall := range firewallsso.Firewalls.Structs {
		//Creating a shallow copy here so the anonymous function has the right reference
		firewall := firewall
		h.spawnSso(ctx, firewall, info, func(info map[string]string) (bool, error) {
			return firewallsso.ExecuteStop(ctx, firewall, info)
		})
	}

	w.WriteHeader(http.StatusAccepted)
}

func (h PfssoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}

}
