package pfdnsconnector

import (
	"context"
	"fmt"
	"time"

	"github.com/coredns/caddy"
	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/plugin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func init() {

	caddy.RegisterPlugin("pfdnsconnector", caddy.Plugin{
		ServerType: "dns",
		Action:     setuppfdnsconnector,
	})
}

type RetryConfig struct {
	MaxAttempts int
	Delay       time.Duration
	Timeout     time.Duration
}

func setuppfdnsconnector(c *caddy.Controller) error {
	var pf = &pfdnsconnector{}
	cfg := RetryConfig{
		MaxAttempts: 20,
		Delay:       2 * time.Second,
		Timeout:     15 * time.Second,
	}

	ctx := context.Background()
	Connectors := connector.NewConnectorsContainer(ctx)
	ctx = connector.WithConnectorsContainer(ctx, Connectors)
	pfconfigdriver.AddType[pfconfigdriver.PfConfDnsConnectors](ctx)
	dnsserver.GetConfig(c).AddPlugin(
		func(next plugin.Handler) plugin.Handler {
			dnsServers := pfconfigdriver.GetType[pfconfigdriver.PfConfDnsConnectors](context.Background())
			for _, dnsRaw := range dnsServers.Element {
				dns, ok := dnsRaw.(map[string]interface{})
				if !ok {
					continue
				}
				for _, proto := range []string{"tcp", "udp"} {

					_, err := connector.OpenConnectionTo(ctx, proto, dns["ip"].(string), dns["port"].(string), dns["pfconnectorport"].(string))
					if err != nil {
						error := RetryWithExponentialBackoff(ctx, cfg, func() error {
							_, err := connector.OpenConnectionTo(ctx, proto, dns["ip"].(string), dns["port"].(string), dns["pfconnectorport"].(string))
							return err
						})
						if error != nil {
							log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to open connection to remote DNS server %s:%s: %v", dns["ip"].(string), dns["port"].(string), error))
						} else {
							log.LoggerWContext(ctx).Info(fmt.Sprintf("Opened connection to remote dns server %s:%s", dns["ip"].(string), dns["port"].(string)))
						}
					}
				}
			}
			pf.Next = next
			return pf
		})

	return nil
}

func RetryWithExponentialBackoff(ctx context.Context, cfg RetryConfig, operation func() error) error {
	var err error
	delay := cfg.Delay

	for attempt := 1; attempt <= cfg.MaxAttempts; attempt++ {
		err = operation()
		if err == nil {
			return nil
		}

		log.LoggerWContext(ctx).Error("Attempt %d failed: %v", attempt, err)

		if attempt == cfg.MaxAttempts {
			break
		}

		// Augment delay
		delay = time.Duration(float64(delay) * 1.5)

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(delay):
			// Continue
		}
	}

	return fmt.Errorf("after %d attempts, last error: %w", cfg.MaxAttempts, err)
}
