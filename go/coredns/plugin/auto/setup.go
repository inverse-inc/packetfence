package auto

import (
	"os"
	"path/filepath"
	"regexp"
	"time"

	"github.com/coredns/caddy"
	"github.com/inverse-inc/packetfence/go/coredns/core/dnsserver"
	"github.com/inverse-inc/packetfence/go/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/metrics"
	clog "github.com/inverse-inc/packetfence/go/coredns/plugin/pkg/log"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/pkg/upstream"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/transfer"
)

var log = clog.NewWithPlugin("auto")

func init() { plugin.Register("auto", setup) }

func setup(c *caddy.Controller) error {
	a, err := autoParse(c)
	if err != nil {
		return plugin.Error("auto", err)
	}

	c.OnStartup(func() error {
		m := dnsserver.GetConfig(c).Handler("prometheus")
		if m != nil {
			(&a).metrics = m.(*metrics.Metrics)
		}
		t := dnsserver.GetConfig(c).Handler("transfer")
		if t != nil {
			(&a).transfer = t.(*transfer.Transfer)
		}
		return nil
	})

	walkChan := make(chan bool)

	c.OnStartup(func() error {
		err := a.Walk()
		if err != nil {
			return err
		}

		go func() {
			ticker := time.NewTicker(a.loader.ReloadInterval)
			for {
				select {
				case <-walkChan:
					return
				case <-ticker.C:
					a.Walk()
				}
			}
		}()
		return nil
	})

	c.OnShutdown(func() error {
		close(walkChan)
		return nil
	})

	dnsserver.GetConfig(c).AddPlugin(func(next plugin.Handler) plugin.Handler {
		a.Next = next
		return a
	})

	return nil
}

func autoParse(c *caddy.Controller) (Auto, error) {
	nilInterval := -1 * time.Second
	var a = Auto{
		loader: loader{
			template:       "${1}",
			re:             regexp.MustCompile(`db\.(.*)`),
			ReloadInterval: nilInterval,
		},
		Zones: &Zones{},
	}

	config := dnsserver.GetConfig(c)

	for c.Next() {
		// auto [ZONES...]
		a.Zones.origins = make([]string, len(c.ServerBlockKeys))
		copy(a.Zones.origins, c.ServerBlockKeys)

		args := c.RemainingArgs()
		if len(args) > 0 {
			a.Zones.origins = args
		}
		for i := range a.Zones.origins {
			a.Zones.origins[i] = plugin.Host(a.Zones.origins[i]).Normalize()
		}
		a.loader.upstream = upstream.New()

		for c.NextBlock() {
			switch c.Val() {
			case "directory": // directory DIR [REGEXP TEMPLATE]
				if !c.NextArg() {
					return a, c.ArgErr()
				}
				a.loader.directory = c.Val()
				if !filepath.IsAbs(a.loader.directory) && config.Root != "" {
					a.loader.directory = filepath.Join(config.Root, a.loader.directory)
				}
				_, err := os.Stat(a.loader.directory)
				if err != nil {
					if os.IsNotExist(err) {
						log.Warningf("Directory does not exist: %s", a.loader.directory)
					} else {
						return a, c.Errf("Unable to access root path '%s': %v", a.loader.directory, err)
					}
				}

				// regexp template
				if c.NextArg() {
					a.loader.re, err = regexp.Compile(c.Val())
					if err != nil {
						return a, err
					}
					if a.loader.re.NumSubexp() == 0 {
						return a, c.Errf("Need at least one sub expression")
					}

					if !c.NextArg() {
						return a, c.ArgErr()
					}
					a.loader.template = rewriteToExpand(c.Val())
				}

				if c.NextArg() {
					return Auto{}, c.ArgErr()
				}

			case "reload":
				d, err := time.ParseDuration(c.RemainingArgs()[0])
				if err != nil {
					return a, plugin.Error("file", err)
				}
				a.loader.ReloadInterval = d

			case "upstream":
				// remove soon
				c.RemainingArgs() // eat remaining args

			default:
				return Auto{}, c.Errf("unknown property '%s'", c.Val())
			}
		}
	}

	if a.loader.ReloadInterval == nilInterval {
		a.loader.ReloadInterval = 60 * time.Second
	}

	return a, nil
}