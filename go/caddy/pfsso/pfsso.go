package pfsso

import (
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/statsd"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/firewallsso"
	pflog "github.com/inverse-inc/packetfence/go/logging"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
	"io"
	"net/http"
	"runtime/debug"
)

func init() {
	caddy.RegisterPlugin("pfsso", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func (h PfssoHandler) handlePing(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handlePing")
	io.WriteString(w, "pong")
}

func (h PfssoHandler) handleStart(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handleStart")
	for _, firewall := range h.firewalls {
		firewallsso.ExecuteStart(ctx, firewall, map[string]string{"ip": "172.20.0.1", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
	}

	io.WriteString(w, "handled")
}

func setup(c *caddy.Controller) error {
	ctx := context.Background()

	pfsso := PfssoHandler{}

	var firewallIds pfconfigdriver.PfconfigKeys
	firewallIds.PfconfigNS = "config::Firewall_SSO"
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &firewallIds)

	fssoFactory := firewallsso.NewFactory(ctx)
	for i := range firewallIds.Keys {
		firewallId := firewallIds.Keys[i]
		log.LoggerWContext(ctx).Info(fmt.Sprintf("Adding firewall %s", firewallId))

		firewall, err := fssoFactory.Instantiate(ctx, firewallId)
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot instantiate firewall %s. Ignoring it.", firewallId))
		} else {
			pfsso.firewalls = append(pfsso.firewalls, firewall)
		}
	}

	router := httprouter.New()
	router.GET("/ping", pfsso.handlePing)
	router.POST("/pfsso/start", pfsso.handleStart)
	//router.POST("/pfsso/stop", pfsso.handleStop)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfsso.Next = next
		pfsso.router = router
		return pfsso
	})

	return nil
}

type PfssoHandler struct {
	Next      httpserver.Handler
	router    *httprouter.Router
	firewalls []firewallsso.FirewallSSOInt
}

func (h PfssoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	//TODO: rework this to use the fingerbank processor logger which is cleaner
	r = r.WithContext(pflog.NewContext(ctx))

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
