package firewallsso

import (
	"context"
	"errors"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type plugin[T any] interface {
	*T
	FirewallSSOInt
	pfconfigdriver.PfconfigObject
}

// A factory for FirewallSSO
type Factory struct {
	typeRegistry map[string]func() FirewallSSOInt
}

func newFirewallSSO[T any, P plugin[T]]() FirewallSSOInt {
	return P(new(T))
}

// Create a new FirewallSSO factory containing all the valid types
func NewFactory(ctx context.Context) Factory {
	f := Factory{}
	f.typeRegistry = map[string]func() FirewallSSOInt{
		"BarracudaNG":      newFirewallSSO[BarracudaNG],
		"Iboss":            newFirewallSSO[Iboss],
		"PaloAlto":         newFirewallSSO[PaloAlto],
		"LightSpeedRocket": newFirewallSSO[FortiGate],
		"SmoothWall":       newFirewallSSO[FortiGate],
		"FortiGate":        newFirewallSSO[FortiGate],
		"Checkpoint":       newFirewallSSO[Checkpoint],
		"WatchGuard":       newFirewallSSO[WatchGuard],
		"JSONRPC":          newFirewallSSO[JSONRPC],
		"JuniperSRX":       newFirewallSSO[JuniperSRX],
		"FamilyZone":       newFirewallSSO[FamilyZone],
		"CiscoIsePic":      newFirewallSSO[CiscoIsePic],
		"ContentKeeper":    newFirewallSSO[ContentKeeper],
	}
	return f
}

// Instantiate a new FirewallSSO given its configuration ID in PacketFence
func (f *Factory) Instantiate(ctx context.Context, id string) (FirewallSSOInt, error) {
	firewall := FirewallSSO{}
	firewall.PfconfigHashNS = id
	_, err := pfconfigdriver.FetchDecodeSocketCache(ctx, &firewall)
	if err != nil {
		return nil, err
	}

	if oType, ok := f.typeRegistry[firewall.Type]; ok {
		fwint := oType()
		fwint.setPfconfigHashNS(id)
		_, err = pfconfigdriver.FetchDecodeSocketCache(ctx, fwint)
		if err != nil {
			return nil, err
		}

		err = fwint.init(ctx)
		if err != nil {
			return nil, err
		}

		err = fwint.initChild(ctx)
		if err != nil {
			return nil, err
		}

		return fwint, nil
	} else {
		return nil, errors.New("Cannot find the type of the object")
	}
}
