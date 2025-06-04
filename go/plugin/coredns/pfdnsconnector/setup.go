package pfdnsconnector

import (
	"context"

	"github.com/coredns/caddy"
	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func init() {

	caddy.RegisterPlugin("pfdnsconnector", caddy.Plugin{
		ServerType: "dns",
		Action:     setuppfdnsconnector,
	})
}

func setuppfdnsconnector(c *caddy.Controller) error {
	var pf = &pfdnsconnector{}

	ctx := context.Background()
	pfconfigdriver.AddType[pfconfigdriver.PfConfDnsConnectors](ctx)

	dnsserver.GetConfig(c).AddPlugin(
		func(next plugin.Handler) plugin.Handler {
			dnsServers := pfconfigdriver.GetType[pfconfigdriver.PfConfDnsConnectors](context.Background())
			for _, dns := range dnsServers.Element {
				for _, proto := range []string{"tcp", "udp"} {
					_, err := connector.OpenConnectionTo(ctx, proto, dns.Ip, dns.PfConnectorPort, dns.PfConnectorPort)
					if err != nil {
						panic(err)
					}
				}
			}
			pf.Next = next
			return pf
		})

	return nil
}
