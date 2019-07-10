package caddyhttpdportalpreview

import (
	"context"
	"net/http"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/httpdportalpreview"
	"github.com/inverse-inc/packetfence/go/panichandler"
)

func init() {
	caddy.RegisterPlugin("httpdportalpreview", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	h := HttpDispatcherHandler{}
	ctx := context.Background()

	proxy := httpdportalpreview.NewProxy(ctx)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		h.Next = next
		h.proxy = proxy
		return h
	})

	return nil
}

type HttpDispatcherHandler struct {
	Next  httpserver.Handler
	proxy *httpdportalpreview.Proxy
}

func (h HttpDispatcherHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	// This will never call the next middleware so make sure its the only «acting» middleware on this service
	h.proxy.ServeHTTP(w, r)

	// TODO change me and wrap actions into something that handles server errors
	return 0, nil
}
