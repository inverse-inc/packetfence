package firewallsso

import (
	"context"
	"errors"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"reflect"
)

// A factory for FirewallSSO
type Factory struct {
	typeRegistry map[string]reflect.Type
}

// Create a new FirewallSSO factory containing all the valid types
func NewFactory(ctx context.Context) Factory {
	f := Factory{}
	f.typeRegistry = make(map[string]reflect.Type)
	f.typeRegistry["Iboss"] = reflect.TypeOf(&Iboss{}).Elem()
	f.typeRegistry["PaloAlto"] = reflect.TypeOf(&PaloAlto{}).Elem()
	return f
}

// Instantiate a new FirewallSSO given its configuration ID in PacketFence
func (f *Factory) Instantiate(ctx context.Context, id string, firstLoad bool) (FirewallSSOInt, error) {
	firewall := FirewallSSO{}
	firewall.PfconfigHashNS = id
	err := pfconfigdriver.GlobalPfconfigResourcePool.LoadResource(ctx, &firewall)
	if err != nil {
		return nil, err
	}
	if oType, ok := f.typeRegistry[firewall.Type]; ok {
		or := reflect.New(oType)
		or.Elem().FieldByName("PfconfigHashNS").SetString(id)
		firewall2 := or.Interface().(pfconfigdriver.PfconfigObject)
		_, err = pfconfigdriver.GlobalPfconfigResourcePool.LoadResource(ctx, &firewall2, firstLoad)
		if err != nil {
			return nil, err
		}

		fwint := firewall2.(FirewallSSOInt)
		fwint.init(ctx)
		return fwint, nil
	} else {
		return nil, errors.New("Cannot find the type of the object")
	}
}
