package caddylog

import (
	"cmp"
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
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/inverse-inc/packetfence/go/requesthistory"
)

func init() {
	caddy.RegisterModule(Logger{})
	httpcaddyfile.RegisterHandlerDirective("logger", utils.ParseCaddyfile[Logger])
}

// CaddyModule returns the Caddy module information.
func (Logger) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.logger",
		New: func() caddy.Module {
			return &Logger{}
		},
	}
}

func (s *Logger) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	for c.Next() {
		for c.NextBlock(0) {
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

				s.HistoryLength = length
				fmt.Printf("Setting up request history with size %d\n", length)
			case "level":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					s.Level = args[0]
				}
			default:
				return c.ArgErr()
			}
		}
	}

	return nil
}

type Logger struct {
	HistoryLength  int                       `json:"history_length"`
	Level          string                    `json:"level"`
	ctx            context.Context           `json:"-"`
	requestHistory *RequestHistoryController `json:"-"`
}

func (l *Logger) Provision(ctx caddy.Context) error {
	l.HistoryLength = cmp.Or(l.HistoryLength, 100)
	l.Level = cmp.Or(l.Level, "INFO")
	fmt.Println("Using configuration set log level: " + l.Level)
	rh, err := requesthistory.NewRequestHistory(l.HistoryLength)
	if err != nil {
		return err
	}

	lctx := log.LoggerAddHandler(
		log.LoggerNewContext(context.Background()),
		func(r *log15.Record) error { return l.requestHistory.requestHistory.HandleLogRecord(r) },
	)

	l.requestHistory = NewRequestHistoryController(&rh)
	l.ctx = log.LoggerSetLevel(lctx, l.Level)
	return nil
}

func (l *Logger) Cleanup() error {
	return nil
}

func (l *Logger) Validate() error {
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

var (
	_ caddy.Provisioner           = (*Logger)(nil)
	_ caddy.CleanerUpper          = (*Logger)(nil)
	_ caddy.Validator             = (*Logger)(nil)
	_ caddyhttp.MiddlewareHandler = (*Logger)(nil)
	_ caddyfile.Unmarshaler       = (*Logger)(nil)
)
