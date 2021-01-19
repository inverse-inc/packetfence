package firewallsso

import (
	"context"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// A struct which contains all the firewall IDs along with their instantiated FirewallSSOInt struct
// It implements pfconfigdriver.Refreshable so that this can be part of a pfconfigdriver.Pool
type FirewallsContainer struct {
	pfconfigdriver.CachedHash
	factory Factory
}

func NewFirewallsContainer(ctx context.Context) *FirewallsContainer {
	fc := &FirewallsContainer{}
	fc.PfconfigNS = "config::Firewall_SSO"
	fc.factory = NewFactory(ctx)
	fc.New = func(ctx context.Context, id string) (pfconfigdriver.PfconfigObject, error) {
		return fc.factory.Instantiate(ctx, id)
	}
	fc.Refresh(ctx)
	return fc
}

func (fc *FirewallsContainer) All(ctx context.Context) map[string]FirewallSSOInt {
	firewalls := map[string]FirewallSSOInt{}
	for id, o := range fc.Structs {
		firewalls[id] = o.(FirewallSSOInt)
	}
	return firewalls
}

func (fc *FirewallsContainer) Get(ctx context.Context, id string) FirewallSSOInt {
	return fc.Structs[id].(FirewallSSOInt)
}
