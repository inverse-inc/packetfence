package caddystatsd

import (
	"context"
	"fmt"
	"net/http"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/statsd"
	_statsd "gopkg.in/alexcesaro/statsd.v2"
)

func init() {
	caddy.RegisterPlugin("statsd", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	ctx := context.Background()

	proto := "udp"
	var prefix string

	for c.Next() {
		for c.NextBlock() {
			switch c.Val() {
			case "proto":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					proto = args[0]
					fmt.Println("Using configured statsd protocol: " + proto)
				}
			case "prefix":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					prefix = args[0]
					fmt.Println("Using configured prefix: " + prefix)
				}
			default:
				return c.ArgErr()
			}
		}
	}

	client, err := _statsd.New(_statsd.Prefix(prefix), _statsd.Network(proto))
	if err != nil {
		fmt.Printf("Couldn't initialize statsd client (%s) \n", err)
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		return Statsd{Next: next, ctx: ctx, client: client}
	})

	return nil
}

type Statsd struct {
	Next   httpserver.Handler
	ctx    context.Context
	client *_statsd.Client
}

func (h Statsd) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	if h.client != nil {
		ctx := statsd.WithContext(r.Context(), h.client)
		r = r.WithContext(ctx)
	}

	return h.Next.ServeHTTP(w, r)
}
