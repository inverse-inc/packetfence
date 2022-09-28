package caddystatsd

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"

	"github.com/inverse-inc/go-utils/statsd"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
	_statsd "gopkg.in/alexcesaro/statsd.v2"
)

func init() {
	caddy.RegisterModule(Statsd{})
	httpcaddyfile.RegisterHandlerDirective("statsd", caddy2.ParseCaddyfile[Statsd])
}

func (h *Statsd) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {

	for c.Next() {
		for nesting := c.Nesting(); c.NextBlock(nesting); {
			switch c.Val() {
			case "proto":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					h.Proto = args[0]
					fmt.Println("Using configured statsd protocol: " + h.Proto)
				}
			case "prefix":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					h.Prefix = args[0]
					fmt.Println("Using configured prefix: " + h.Prefix)
				}
			case "address":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					address := args[0]
					if !strings.Contains(address, ":") {
						address = fmt.Sprintf("%s%s", address, ":8125")
					}

					h.Address = address
					fmt.Println("Using configured statsd address and port: " + address)
				}
			default:
				return c.ArgErr()
			}
		}
	}

	return nil
}

func (h *Statsd) Provision(ctx caddy.Context) error {
	client, err := _statsd.New(_statsd.Prefix(h.Prefix), _statsd.Network(h.Proto), _statsd.Address(h.Address))
	if err != nil {
		fmt.Printf("Couldn't initialize statsd client (%s) \n", err.Error())
	}

	h.client = client
	return nil
}

type Statsd struct {
	caddy2.ModuleBase
	ctx     context.Context
	client  *_statsd.Client
	Proto   string `json:"proto"`
	Prefix  string `json:"prefix"`
	Address string `json:"address"`
}

func (h Statsd) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.statsd",
		New: func() caddy.Module { return &Statsd{Proto: "udp", Address: "127.0.0.1:8125"} },
	}
}

func (h Statsd) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	if h.client != nil {
		ctx := statsd.WithContext(r.Context(), h.client)
		r = r.WithContext(ctx)
	}

	return next.ServeHTTP(w, r)
}
