package caddyhttpdispatcher

import (
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/httpdispatcher"
	"net/http"
	"runtime/debug"
)

func init() {
	caddy.RegisterPlugin("httpdispatcher", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	h := HttpDispatcherHandler{}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		h.Next = next
		//TODO: change this to use the caddy logger
		h.proxy = httpdispatcher.NewProxy(context.Background())
		return h
	})

	return nil
}

type HttpDispatcherHandler struct {
	Next  httpserver.Handler
	proxy *httpdispatcher.Proxy
}

func (h HttpDispatcherHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer func() {
		if r := recover(); r != nil {
			msg := fmt.Sprintf("Recovered panic: %s.", r)
			log.LoggerWContext(ctx).Error(msg)
			fmt.Println(msg)
			debug.PrintStack()
			http.Error(w, "An internal error has occured, please check server side logs for details.", http.StatusInternalServerError)
		}
	}()

	// This will never call the next middleware so make sure its the only «acting» middleware on this service
	h.proxy.ServeHTTP(w, r)

	// TODO change me and wrap actions into something that handles server errors
	return 0, nil
}
