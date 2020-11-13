package any

import (
	"github.com/coredns/caddy"
	"github.com/inverse-inc/packetfence/go/coredns/core/dnsserver"
	"github.com/inverse-inc/packetfence/go/coredns/plugin"
)

func init() { plugin.Register("any", setup) }

func setup(c *caddy.Controller) error {
	a := Any{}

	dnsserver.GetConfig(c).AddPlugin(func(next plugin.Handler) plugin.Handler {
		a.Next = next
		return a
	})

	return nil
}
