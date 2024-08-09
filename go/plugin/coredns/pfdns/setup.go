package pfdns

import (
	"context"
	"net"
	"time"

	"github.com/coredns/caddy"
	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/timedlock"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

func init() {
	GlobalTransactionLock = timedlock.NewRWLock()
	GlobalTransactionLock.Panic = false
	GlobalTransactionLock.PrintErrors = true
	caddy.RegisterPlugin("pfdns", caddy.Plugin{
		ServerType: "dns",
		Action:     setuppfdns,
	})
}

func setuppfdns(c *caddy.Controller) error {
	var pf = &pfdns{}
	var ip net.IP
	pf.Network = make(map[string]net.IP)
	ctx := context.Background()
	pfconfigdriver.AddType[pfconfigdriver.PfConfGeneral](ctx)
	pfconfigdriver.AddType[pfconfigdriver.PfConfCaptivePortal](ctx)
	pfconfigdriver.AddType[pfconfigdriver.ListenInts](ctx)
	pfconfigdriver.AddType[pfconfigdriver.DNSInts](ctx)

	for c.Next() {
		// block with extra parameters
		for c.NextBlock() {
			switch c.Val() {

			case "redirectTo":
				arg := c.RemainingArgs()
				ip = net.ParseIP(arg[0])
				if ip == nil {
					return c.Errf("Invalid IP address '%s'", c.Val())
				}
			default:
				return c.Errf("Unknown keyword '%s'", c.Val())
			}
		}
	}
	pfdnsRefreshableConfig := newPfconfigRefreshableConfig(ctx)
	pfconfigdriver.AddRefreshable(ctx, "pfdnsRefreshableConfig", pfdnsRefreshableConfig)

	if err := pf.DbInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize database connection")
	}

	if err := pf.WebservicesInit(ctx); err != nil {
		return c.Errf("pfdns: unable to fetch Webservices credentials")
	}

	if err := pf.detectVIP(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize the vip network map")
	}

	if err := pf.DomainPassthroughInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize domain passthrough")
	}

	if err := pf.detectType(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize Network Type")
	}

	if err := pf.PortalFQDNInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize Portal FQDN")
	}

	if err := pf.MakeDetectionMecanism(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize Detection Mecanism List")
	}

	if err := pf.SetupRedisClient(); err != nil {
		return c.Errf("pfdns: unable to setup redis client")
	}

	pf.apiClient = unifiedapiclient.NewFromConfig(context.Background())

	go func() {
		for {
			pfconfigdriver.PfConfigStorePool.Refresh(context.Background())
			time.Sleep(time.Second * 1)
		}
	}()

	dnsserver.GetConfig(c).AddPlugin(
		func(next plugin.Handler) plugin.Handler {
			captivePortal := pfconfigdriver.GetType[pfconfigdriver.PfConfCaptivePortal](context.Background())
			pf.InternalPortalIP = net.ParseIP(captivePortal.IpAddress).To4()
			pf.RedirectIP = ip
			pf.Next = next
			return pf
		})

	return nil
}
