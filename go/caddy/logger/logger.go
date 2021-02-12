package caddylog

import (
	"context"
	"fmt"
	"net/http"
	"strconv"

	"github.com/inconshreveable/log15"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/requesthistory"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

func init() {
	caddy.RegisterPlugin("logger", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	ctx := context.Background()
	ctx = log.LoggerNewContext(ctx)

	var requestHistory *RequestHistoryController

	for c.Next() {
		for c.NextBlock() {
			switch c.Val() {
			case "requesthistory":
				args := c.RemainingArgs()
				var length int
				if len(args) == 0 {
					length = 100
				} else {
					length64, err := strconv.ParseInt(args[0], 10, 32)
					sharedutils.CheckError(err)
					length = int(length64)
				}

				fmt.Printf("Setting up request history with size %d\n", length)

				rh, err := requesthistory.NewRequestHistory(length)
				sharedutils.CheckError(err)

				requestHistory = NewRequestHistoryController(&rh)

				ctx = log.LoggerAddHandler(ctx, func(r *log15.Record) error { return requestHistory.requestHistory.HandleLogRecord(r) })
			case "level":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					level := args[0]
					fmt.Println("Using configuration set log level: " + level)
					ctx = log.LoggerSetLevel(ctx, level)
				}
			default:
				return c.ArgErr()
			}
		}
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		return Logger{Next: next, ctx: ctx, requestHistory: requestHistory}
	})

	return nil
}

type Logger struct {
	Next           httpserver.Handler
	ctx            context.Context
	requestHistory *RequestHistoryController
}

func (h Logger) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := log.TranferLogContext(h.ctx, r.Context())
	ctx = log.LoggerNewRequest(ctx)
	r = r.WithContext(ctx)

	if h.requestHistory != nil {
		if handle, params, _ := h.requestHistory.router.Lookup(r.Method, r.URL.Path); handle != nil {
			handle(w, r, params)
			// TODO change me and wrap actions into something that handles server errors
			return 0, nil
		}
	}

	return h.Next.ServeHTTP(w, r)
}
