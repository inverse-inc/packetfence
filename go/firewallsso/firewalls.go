package firewallsso

import (
	"context"
	"fmt"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// Global variable that can be used in a pfconfigdriver.Pool
var Firewalls FirewallsContainer

// A struct which contains all the firewall IDs along with their instantiated FirewallSSOInt struct
// It implements pfconfigdriver.Refreshable so that this can be part of a pfconfigdriver.Pool
// TODO: This should be reworked into a generalized method of loading these type of PacketFence resources (like provisioners, PKI providers, ...)
type FirewallsContainer struct {
	ids     pfconfigdriver.PfconfigKeys
	Structs map[string]FirewallSSOInt
}

// Refresh the FirewallsContainer struct
// Will first check if the IDs have changed in pfconfig and reload if they did
// Then it will check if all the IDs in pfconfig are loaded and valid and reload otherwise
func (f *FirewallsContainer) Refresh(ctx context.Context) {
	reload := false

	f.ids.PfconfigNS = "config::Firewall_SSO"

	// If ids changed, we want to reload
	if !pfconfigdriver.IsValid(ctx, &f.ids) {
		reload = true
	}

	pfconfigdriver.FetchDecodeSocketCache(ctx, &f.ids)

	fssoFactory := NewFactory(ctx)

	if f.Structs != nil {
		for _, firewallId := range f.ids.Keys {
			firewall, ok := f.Structs[firewallId]

			if !ok {
				log.LoggerWContext(ctx).Info("A firewall was added. Will read the firewalls again.")
				reload = true
				break
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
