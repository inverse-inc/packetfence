package tls

import (
	"github.com/inverse-inc/packetfence/go/coredns/core/dnsserver"
	"github.com/inverse-inc/packetfence/go/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/pkg/tls"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
)

func init() {
	caddy.RegisterPlugin("tls", caddy.Plugin{
		ServerType: "dns",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	config := dnsserver.GetConfig(c)

	if config.TLSConfig != nil {
		return plugin.Error("tls", c.Errf("TLS already configured for this server instance"))
	}

	for c.Next() {
		args := c.RemainingArgs()
		if len(args) != 3 {
			return plugin.Error("tls", c.ArgErr())
		}
		tls, err := tls.NewTLSConfig(args[0], args[1], args[2])
		if err != nil {
			return plugin.Error("tls", err)
		}
		config.TLSConfig = tls
	}
	return nil
}
