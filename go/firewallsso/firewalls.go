package firewallsso

import (
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var Firewalls FirewallsContainer

type FirewallsContainer struct {
	ids     pfconfigdriver.PfconfigKeys
	Structs map[string]FirewallSSOInt
}

func (f *FirewallsContainer) Refresh(ctx context.Context) {
	f.ids.PfconfigNS = "config::Firewall_SSO"
	pfconfigdriver.FetchDecodeSocketCache(ctx, &f.ids)

	fssoFactory := NewFactory(ctx)

	reload := false
	if f.Structs != nil {
		for _, firewallId := range f.ids.Keys {
			firewall, ok := f.Structs[firewallId]

			if !ok {
				log.LoggerWContext(ctx).Info("A firewall was added. Will read the firewalls again.")
				reload = true
			}

			if !pfconfigdriver.IsValid(ctx, firewall) {
				log.LoggerWContext(ctx).Info(fmt.Sprintf("Firewall %s has been detected as expired in pfconfig. Reloading.", firewallId))
				reload = true
			}
		}
	} else {
		reload = true
	}

	if reload {
		newFirewalls := make(map[string]FirewallSSOInt)

		for _, firewallId := range f.ids.Keys {
			log.LoggerWContext(ctx).Info(fmt.Sprintf("Adding firewall %s", firewallId))

			firewall, err := fssoFactory.Instantiate(ctx, firewallId)
			if err != nil {
				log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot instantiate firewall %s because of an error (%s). Ignoring it.", firewallId, err))
			} else {
				newFirewalls[firewall.GetFirewallSSO(ctx).PfconfigHashNS] = firewall
			}
		}
		f.Structs = newFirewalls
	}
}
