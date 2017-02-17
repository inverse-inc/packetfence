package pfsso

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/davecgh/go-spew/spew"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/statsd"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/firewallsso"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
	"net/http"
	"runtime/debug"
	"strconv"
)

func init() {
	caddy.RegisterPlugin("pfsso", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func (h PfssoHandler) handleStart(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStart")

	var info map[string]string
	json.NewDecoder(r.Body).Decode(&info)

	for _, firewall := range h.firewalls {
		// Creating a local shallow copy to send to the go-routine
		firewall := firewall
		go func() {
			timeout, err := strconv.ParseInt(info["timeout"], 10, 32)
			if err != nil {
				log.LoggerWContext(ctx).Warn(fmt.Sprintf("Can't parse timeout '%s' into an int (%s). Will not specify timeout for request.", info["timeout"], err))
			}
			firewallsso.ExecuteStart(ctx, firewall, info, int(timeout))
		}()
	}

	w.WriteHeader(http.StatusAccepted)
}

func (h PfssoHandler) handleStop(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStop")

	w.WriteHeader(http.StatusNotImplemented)
}

func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfsso := PfssoHandler{
		firewalls: make(map[string]firewallsso.FirewallSSOInt),
	}
	readConfig(ctx, &pfsso, true)

	router := httprouter.New()
	router.POST("/pfsso/start", pfsso.handleStart)
	router.POST("/pfsso/stop", pfsso.handleStop)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfsso.Next = next
		pfsso.router = router
		return pfsso
	})

	return nil
}

func readConfig(ctx context.Context, pfsso *PfssoHandler, firstLoad bool) error {
	pfconfigdriver.GlobalPfconfigResourcePool.LoadResourceStruct(ctx, &pfsso.firewallIds, firstLoad)

	fssoFactory := firewallsso.NewFactory(ctx)

	if !firstLoad {
		for _, firewallId := range pfsso.firewallIds.Keys {
			firewall, ok := pfsso.firewalls[firewallId]

			if !ok {
				return readConfig(ctx, pfsso, true)
			}

			res, ok := pfconfigdriver.GlobalPfconfigResourcePool.FindResource(ctx, &firewall)
			if ok && res.IsValid(ctx) {
				log.LoggerWContext(ctx).Info(fmt.Sprintf("Firewall %s is still valid", firewallId))
			} else {
				log.LoggerWContext(ctx).Info(fmt.Sprintf("Firewall %s is not valid", firewallId))
				return readConfig(ctx, pfsso, true)
			}
		}
	} else {
		firewalls := make(map[string]firewallsso.FirewallSSOInt)

		for _, firewallId := range pfsso.firewallIds.Keys {
			log.LoggerWContext(ctx).Info(fmt.Sprintf("Adding firewall %s", firewallId))

			firewall, err := fssoFactory.Instantiate(ctx, firewallId, false)
			if err != nil {
				log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot instantiate firewall %s because of an error (%s). Ignoring it.", firewallId, err))
			} else {
				firewalls[firewall.GetFirewallSSO(ctx).PfconfigHashNS] = firewall
			}
		}
		pfsso.firewalls = firewalls

	}

	return nil
}

type PfssoHandler struct {
	Next        httpserver.Handler
	router      *httprouter.Router
	firewallIds firewallsso.FirewallIds
	firewalls   map[string]firewallsso.FirewallSSOInt
}

func (h PfssoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()
	readConfig(ctx, &h, false)

	defer func() {
		if r := recover(); r != nil {
			msg := fmt.Sprintf("Recovered panic: %s.", r)
			log.LoggerWContext(ctx).Error(msg)
			fmt.Println(msg)
			debug.PrintStack()
			http.Error(w, "An internal error has occured, please check server side logs for details.", http.StatusInternalServerError)
		}
	}()

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)
		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}
}
