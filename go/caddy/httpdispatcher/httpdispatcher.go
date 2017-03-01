package caddyhttpdispatcher

import (
	"context"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/httpdispatcher"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"net/http"
)

func init() {
	caddy.RegisterPlugin("httpdispatcher", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	h := HttpDispatcherHandler{}
	ctx := context.Background()

	proxy := httpdispatcher.NewProxy(ctx)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Trapping)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.General)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.CaptivePortal)
	pfconfigdriver.PfconfigPool.AddRefreshable(ctx, proxy)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		h.Next = next
		//TODO: change this to use the caddy logger
		h.proxy = proxy
		return h
	})

	return nil
}

type HttpDispatcherHandler struct {
	Next  httpserver.Handler
	proxy *httpdispatcher.Proxy
}

func (h HttpDispatcherHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	// This will never call the next middleware so make sure its the only «acting» middleware on this service
	h.proxy.ServeHTTP(w, r)

	// TODO change me and wrap actions into something that handles server errors
	return 0, nil
}
