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
	timeout, err := strconv.ParseInt(info["timeout"], 10, 32)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Can't parse timeout '%s' into an int (%s). Will not specify timeout for request.", info["timeout"], err))
	}

	for _, firewall := range firewallsso.Firewalls.Structs {
		// Creating a local shallow copy to send to the go-routine
		firewall := firewall
		go func() {
			if !firewallsso.ExecuteStart(ctx, firewall, info, int(timeout)) {
				log.LoggerWContext(ctx).Error("Failed to send SSO start to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
			} else {
				log.LoggerWContext(ctx).Debug("Sent SSO start to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
			}
		}()
	}

	w.WriteHeader(http.StatusAccepted)
}

func (h PfssoHandler) handleStop(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStop")

	var info map[string]string
	json.NewDecoder(r.Body).Decode(&info)
	timeout, err := strconv.ParseInt(info["timeout"], 10, 32)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Can't parse timeout '%s' into an int (%s). Will not specify timeout for request.", info["timeout"], err))
	}

	for _, firewall := range firewallsso.Firewalls.Structs {
		// Creating a local shallow copy to send to the go-routine
		firewall := firewall
		go func() {
			if !firewallsso.ExecuteStop(ctx, firewall, info, int(timeout)) {
				log.LoggerWContext(ctx).Error("Failed to send SSO stop to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
			} else {
				log.LoggerWContext(ctx).Debug("Sent SSO start to " + firewall.GetFirewallSSO(ctx).PfconfigHashNS)
			}
		}()
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

	router := httprouter.New()
	router.POST("/pfsso/start", pfsso.handleStart)
	router.POST("/pfsso/stop", pfsso.handleStop)

	pfsso.router = router

	return pfsso, nil
}

type PfssoHandler struct {
	Next   httpserver.Handler
	router *httprouter.Router
}

func (h PfssoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()
	pfconfigdriver.PfconfigPool.Refresh(ctx)

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
