package utils

import (
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
)

type Plugin[T any] interface {
	*T
	caddyfile.Unmarshaler
	caddyhttp.MiddlewareHandler
}

// parseCaddyfile unmarshals tokens from h into a new Middleware.
func ParseCaddyfile[T any, P Plugin[T]](h httpcaddyfile.Helper) (caddyhttp.MiddlewareHandler, error) {
	m := P(new(T))
	err := m.UnmarshalCaddyfile(h.Dispenser)
	if err != nil {
		return nil, err
	}

	return m, err
}
