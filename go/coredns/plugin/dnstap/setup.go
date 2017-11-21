package dnstap

import (
	"fmt"
	"io"
	"log"
	"strings"

	"github.com/inverse-inc/packetfence/go/coredns/core/dnsserver"
	"github.com/inverse-inc/packetfence/go/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/dnstap/dnstapio"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/dnstap/out"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/pkg/dnsutil"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyfile"
)

func init() {
	caddy.RegisterPlugin("dnstap", caddy.Plugin{
		ServerType: "dns",
		Action:     wrapSetup,
	})
}

func wrapSetup(c *caddy.Controller) error {
	if err := setup(c); err != nil {
		return plugin.Error("dnstap", err)
	}
	return nil
}

type config struct {
	target string
	socket bool
	full   bool
}

func parseConfig(d *caddyfile.Dispenser) (c config, err error) {
	d.Next() // directive name

	if !d.Args(&c.target) {
		return c, d.ArgErr()
	}

	if strings.HasPrefix(c.target, "tcp://") {
		// remote IP endpoint
		servers, err := dnsutil.ParseHostPortOrFile(c.target[6:])
		if err != nil {
			return c, d.ArgErr()
		}
		c.target = servers[0]
	} else {
		// default to UNIX socket
		if strings.HasPrefix(c.target, "unix://") {
			c.target = c.target[7:]
		}
		c.socket = true
	}

	c.full = d.NextArg() && d.Val() == "full"

	return
}

func setup(c *caddy.Controller) error {
	conf, err := parseConfig(&c.Dispenser)
	if err != nil {
		return err
	}

	dnstap := Dnstap{Pack: conf.full}

	var o io.WriteCloser
	if conf.socket {
		o, err = out.NewSocket(conf.target)
		if err != nil {
			log.Printf("[WARN] Can't connect to %s at the moment: %s", conf.target, err)
		}
	} else {
		o = out.NewTCP(conf.target)
	}
	dio := dnstapio.New(o)
	dnstap.IO = dio

	c.OnShutdown(func() error {
		if err := dio.Close(); err != nil {
			return fmt.Errorf("dnstap io routine: %s", err)
		}
		return nil
	})

	dnsserver.GetConfig(c).AddPlugin(
		func(next plugin.Handler) plugin.Handler {
			dnstap.Next = next
			return dnstap
		})

	return nil
}
