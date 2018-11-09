package caddylog

import (
	"context"
	"fmt"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/coredns/core/dnsserver"
	"github.com/inverse-inc/packetfence/go/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/miekg/dns"
)

func init() {
	caddy.RegisterPlugin("logger", caddy.Plugin{
		ServerType: "dns",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	ctx := context.Background()
	ctx = log.LoggerNewContext(ctx)

	for c.Next() {
		for c.NextBlock() {
			switch c.Val() {
			case "level":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					level := args[0]
					fmt.Println("Using configuration set log level: " + level)
					ctx = log.LoggerSetLevel(ctx, level)
				}
			case "processname":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					name := args[0]
					fmt.Println("Using configuration set processname: " + name)
					log.SetProcessName(name)
				}
			default:
				return c.ArgErr()
			}
		}
	}

	dnsserver.GetConfig(c).AddPlugin(func(next plugin.Handler) plugin.Handler {
		return Logger{Next: next, ctx: ctx}
	})

	return nil
}

type Logger struct {
	Next plugin.Handler
	ctx  context.Context
}

// Name implements the Handler interface.
func (l Logger) Name() string { return "logger" }

func (l Logger) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) (int, error) {
	ctx = log.TranferLogContext(l.ctx, ctx)
	ctx = log.LoggerNewRequest(ctx)
	return l.Next.ServeDNS(ctx, w, r)
}
