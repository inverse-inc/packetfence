package pfsso

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/statsd"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/firewallsso"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
	"github.com/patrickmn/go-cache"
	"io"
	"net/http"
	"strconv"
	"time"
)

func init() {
	caddy.RegisterPlugin("pfsso", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func (h PfssoHandler) parseBody(ctx context.Context, body io.Reader) (map[string]string, int) {
	var info map[string]string
	json.NewDecoder(body).Decode(&info)
	timeout, err := strconv.ParseInt(info["timeout"], 10, 32)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Can't parse timeout '%s' into an int (%s). Will not specify timeout for request.", info["timeout"], err))
	}

	return info, int(timeout)
}

func (h PfssoHandler) spawnSso(ctx context.Context, firewall firewallsso.FirewallSSOInt, f func() (bool, error)) {
	go func() {
		defer panichandler.Standard(ctx)
		sent, err := f()
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while sending SSO to %s: %s"+firewall.GetFirewallSSO(ctx).PfconfigHashNS, err))
		}

		if sent {
			log.LoggerWContext(ctx).Debug("Sent SSO to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
		} else {
			log.LoggerWContext(ctx).Debug("Couldn't send SSO to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
		}
	}()
}

func (h PfssoHandler) addInfoToContext(ctx context.Context, info map[string]string) context.Context {
	return log.AddToLogContext(ctx, "ip", info["ip"], "mac", info["mac"], "role", info["role"])
}

func (h PfssoHandler) handleUpdate(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleUpdate")

	info, timeout := h.parseBody(ctx, r.Body)
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
			h.spawnSso(ctx, firewall, func() (bool, error) {
				return firewallsso.ExecuteStart(ctx, firewall, info, timeout)
			})
		} else {
			log.LoggerWContext(ctx).Debug("Determined that SSO start was not necessary for this update")
		}

	}

	w.WriteHeader(http.StatusAccepted)
}

func (h PfssoHandler) handleStart(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStart")

	info, timeout := h.parseBody(ctx, r.Body)
	ctx = h.addInfoToContext(ctx, info)

	for _, firewall := range firewallsso.Firewalls.Structs {
		//Creating a shallow copy here so the anonymous function has the right reference
		firewall := firewall
		h.spawnSso(ctx, firewall, func() (bool, error) {
			return firewallsso.ExecuteStart(ctx, firewall, info, timeout)
		})
	}

	w.WriteHeader(http.StatusAccepted)
}

func (h PfssoHandler) handleStop(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStop")

	info, _ := h.parseBody(ctx, r.Body)
	ctx = h.addInfoToContext(ctx, info)

	for _, firewall := range firewallsso.Firewalls.Structs {
		//Creating a shallow copy here so the anonymous function has the right reference
		firewall := firewall
		h.spawnSso(ctx, firewall, func() (bool, error) {
			return firewallsso.ExecuteStop(ctx, firewall, info)
		})
	}

	w.WriteHeader(http.StatusAccepted)
}

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

func buildPfssoHandler(ctx context.Context) (PfssoHandler, error) {

	pfsso := PfssoHandler{}

	pfsso.updateCache = cache.New(1*time.Hour, 30*time.Second)

	router := httprouter.New()
	router.POST("/pfsso/update", pfsso.handleUpdate)
	router.POST("/pfsso/start", pfsso.handleStart)
	router.POST("/pfsso/stop", pfsso.handleStop)

	pfsso.router = router

	return pfsso, nil
}

type PfssoHandler struct {
	Next        httpserver.Handler
	router      *httprouter.Router
	updateCache *cache.Cache
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
