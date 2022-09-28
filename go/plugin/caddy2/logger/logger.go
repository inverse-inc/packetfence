package caddylog

import (
	"context"
	"fmt"
	"net/http"
	"strconv"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"

	"github.com/inconshreveable/log15"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
	"github.com/inverse-inc/packetfence/go/requesthistory"
)

func init() {
	caddy.RegisterModule(Logger{})
	httpcaddyfile.RegisterHandlerDirective("logger", caddy2.ParseCaddyfile[Logger])
}

type Logger struct {
	caddy2.ModuleBase
	ctx            context.Context
	requestHistory *RequestHistoryController
	Level          string `json:"level"`
	RequestHistory int
}

func (h Logger) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.logger",
		New: func() caddy.Module { return &Logger{RequestHistory: 100} },
	}
}

func (h *Logger) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	ctx := context.Background()
	ctx = log.LoggerNewContext(ctx)

	h.RequestHistory = 100
	for c.Next() {
		for nesting := c.Nesting(); c.NextBlock(nesting); {
			switch c.Val() {
			case "requesthistory":
				args := c.RemainingArgs()
				var length int
				if len(args) == 0 {
					h.RequestHistory = 100
				} else {
					length64, err := strconv.ParseInt(args[0], 10, 32)
					sharedutils.CheckError(err)
					h.RequestHistory = int(length64)
				}

				fmt.Printf("Setting up request history with size %d\n", length)

			case "level":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				}

				h.Level = args[0]
			default:
				return c.ArgErr()
			}
		}
	}

	return nil
}

func (h *Logger) Provision(ctx caddy.Context) error {
	h.ctx = context.Background()
	h.ctx = log.LoggerNewContext(h.ctx)
	h.ctx = log.LoggerSetLevel(h.ctx, h.Level)
	fmt.Println("Using configuration set log level: " + h.Level)
	rh, err := requesthistory.NewRequestHistory(h.RequestHistory)
	sharedutils.CheckError(err)
	h.requestHistory = NewRequestHistoryController(&rh)
	h.ctx = log.LoggerAddHandler(h.ctx, func(r *log15.Record) error { return h.requestHistory.requestHistory.HandleLogRecord(r) })
	return nil
}

func (h *Logger) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := log.TranferLogContext(h.ctx, r.Context())
	ctx = log.LoggerNewRequest(ctx)
	r = r.WithContext(ctx)

	if h.requestHistory != nil {
		if handle, params, _ := h.requestHistory.router.Lookup(r.Method, r.URL.Path); handle != nil {
			handle(w, r, params)
			// TODO change me and wrap actions into something that handles server errors
			return nil
		}
	}

	return next.ServeHTTP(w, r)
}
