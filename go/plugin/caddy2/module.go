package caddy2

import (
	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
)

type ModuleBase struct{}

func (h ModuleBase) Validate() error {
	return nil
}

func (h ModuleBase) Provision(ctx caddy.Context) error {
	return nil
}

func (h ModuleBase) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	return nil
}
