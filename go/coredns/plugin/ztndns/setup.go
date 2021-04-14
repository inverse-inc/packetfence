package ztndns

import (
	"context"
	"sync"

	"github.com/coredns/caddy"
	"github.com/inverse-inc/packetfence/go/coredns/core/dnsserver"
	"github.com/inverse-inc/packetfence/go/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/timedlock"
)

func init() {
	GlobalTransactionLock = timedlock.NewRWLock()
	GlobalTransactionLock.Panic = false
	GlobalTransactionLock.PrintErrors = true
	caddy.RegisterPlugin("ztndns", caddy.Plugin{
		ServerType: "dns",
		Action:     setupztndns,
	})
}

func setupztndns(c *caddy.Controller) error {
	var ztn = &ztndns{}

	ctx := context.Background()

	for c.Next() {
		// block with extra parameters
		for c.NextBlock() {
			switch c.Val() {

			default:
				return c.Errf("Unknown keyword '%s'", c.Val())
			}
		}
	}

	if err := ztn.DbInit(ctx); err != nil {
		return c.Errf("ztn: unable to initialize database connection")
	}
	if err := ztn.HostIPMAP(ctx); err != nil {
		log.LoggerWContext(ctx).Info(err.Error())
		return c.Errf("ztn: unable to initialize HostMAP")
	}

	ztn.refreshLauncher = &sync.Once{}

	dnsserver.GetConfig(c).AddPlugin(
		func(next plugin.Handler) plugin.Handler {
			ztn.Next = next
			return ztn
		})

	return nil
}
