package pfdns

import (
	"fmt"
	"net"
	"strings"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/coredns/core/dnsserver"
	"github.com/inverse-inc/packetfence/go/coredns/plugin"
)

func init() {
	caddy.RegisterPlugin("pfdns", caddy.Plugin{
		ServerType: "dns",
		Action:     setuppfdns,
	})
}

func setuppfdns(c *caddy.Controller) error {
	var pf = &pfdns{}
	var ip net.IP
	enforce := false

	for c.Next() {
		// block with extra parameters
		var hadBlock bool
		for c.NextBlock() {
			hadBlock = true
			switch c.Val() {
			case "enforcement":
				arg := c.RemainingArgs()
				if strings.ToUpper(arg[0]) == "FALSE" {
					enforce = false
				} else if strings.ToUpper(arg[0]) == "TRUE" {
					enforce = true
				} else {
					return c.Errf("Wrong value type name or value type not supported: '%s'", c.Val())
				}
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
		if !(hadBlock) {
			return c.Errf("pfdns: missing configuration")
		}
	}

	if enforce {
		if err := pf.DbInit(); err != nil {
			return c.Errf("pfdns: unable to initialize database connection")
		}
		fmt.Println("pfdns: Enforcement mode enabled.")
	}
	if err := pf.PassthrouthsInit(); err != nil {
		return c.Errf("pfdns: unable to initialize passthrough")
	}
	if err := pf.PassthrouthsIsolationInit(); err != nil {
		return c.Errf("pfdns: unable to initialize isolation passthrough")
	}

	if err := pf.WebservicesInit(); err != nil {
		return c.Errf("pfdns: unable to fetch Webservices credentials")
	}

	if err := pf.detectVIP(); err != nil {
		return c.Errf("pfdns: unable to initialize the vip network map")
	}

	if err := pf.DomainPassthroughInit(); err != nil {
		return c.Errf("pfdns: unable to initialize domain passthrough")
	}

	if err := pf.detectType(); err != nil {
		return c.Errf("pfdns: unable to initialize Network Type")
	}

	dnsserver.GetConfig(c).AddPlugin(
		func(next plugin.Handler) plugin.Handler {
			pf.RedirectIP = ip
			pf.Enforce = enforce
			pf.Next = next
			return pf
		})

	return nil
}
