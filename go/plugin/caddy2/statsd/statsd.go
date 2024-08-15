package pfstatsd

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
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"go.uber.org/zap"
	_statsd "gopkg.in/alexcesaro/statsd.v2"
)

func init() {
	caddy.RegisterModule(Statsd{})
	httpcaddyfile.RegisterHandlerDirective("statsd", utils.ParseCaddyfile[Statsd])
}

// CaddyModule returns the Caddy module information.
func (Statsd) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.statsd",
		New: func() caddy.Module {
			return &Statsd{
				Proto:   "udp",
				Address: "127.0.0.1:8125",
			}
		},
	}
}

func (s *Statsd) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	for c.Next() {
		for c.NextBlock(0) {
			switch c.Val() {
			case "proto":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					s.Proto = args[0]
					fmt.Println("Using configured statsd protocol: " + s.Proto)
				}
			case "prefix":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					s.Prefix = args[0]
					fmt.Println("Using configured prefix: " + s.Prefix)
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
					s.Address = address
					fmt.Println("Using configured statsd addresse and port: " + s.Address)
				}
			default:
				return c.ArgErr()
			}
		}
	}

	return nil
}

func (m *Statsd) Provision(ctx caddy.Context) error {
	client, err := _statsd.New(
		_statsd.Prefix(m.Prefix),
		_statsd.Network(m.Proto),
		_statsd.Address(m.Address),
	)

	m.ctx = context.Background()

	if err != nil {
		ctx.Logger().Info("Couldn't initialize statsd client (%s) \n", zap.Error(err))
	} else {
		m.client = client
	}
	return nil
}

type Statsd struct {
	Proto   string          `json:"proto"`
	Prefix  string          `json:"prefix"`
	Address string          `json:"address"`
	ctx     context.Context `json:"-"`
	client  *_statsd.Client `json:"-"`
}

func (h *Statsd) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	if h.client != nil {
		ctx := statsd.WithContext(r.Context(), h.client)
		r = r.WithContext(ctx)
	}

	return next.ServeHTTP(w, r)
}

func (h *Statsd) Cleanup() error {
	return nil
}

func (h *Statsd) Validate() error {
	return nil
}

var (
	_ caddy.Provisioner           = (*Statsd)(nil)
	_ caddy.CleanerUpper          = (*Statsd)(nil)
	_ caddy.Validator             = (*Statsd)(nil)
	_ caddyhttp.MiddlewareHandler = (*Statsd)(nil)
	_ caddyfile.Unmarshaler       = (*Statsd)(nil)
)
