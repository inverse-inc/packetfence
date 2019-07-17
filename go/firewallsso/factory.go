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
	f.typeRegistry["BarracudaNG"] = reflect.TypeOf(&BarracudaNG{}).Elem()
	f.typeRegistry["Iboss"] = reflect.TypeOf(&Iboss{}).Elem()
	f.typeRegistry["PaloAlto"] = reflect.TypeOf(&PaloAlto{}).Elem()
	f.typeRegistry["LightSpeedRocket"] = reflect.TypeOf(&FortiGate{}).Elem()
	f.typeRegistry["SmoothWall"] = reflect.TypeOf(&FortiGate{}).Elem()
	f.typeRegistry["FortiGate"] = reflect.TypeOf(&FortiGate{}).Elem()
	f.typeRegistry["Checkpoint"] = reflect.TypeOf(&Checkpoint{}).Elem()
	f.typeRegistry["WatchGuard"] = reflect.TypeOf(&WatchGuard{}).Elem()
	f.typeRegistry["JSONRPC"] = reflect.TypeOf(&JSONRPC{}).Elem()
	f.typeRegistry["JuniperSRX"] = reflect.TypeOf(&JuniperSRX{}).Elem()
	f.typeRegistry["FamilyZone"] = reflect.TypeOf(&FamilyZone{}).Elem()
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
		or := reflect.New(oType)
		or.Elem().FieldByName("PfconfigHashNS").SetString(id)
		firewall2 := or.Interface().(pfconfigdriver.PfconfigObject)
		_, err = pfconfigdriver.FetchDecodeSocketCache(ctx, firewall2)
		if err != nil {
			return nil, err
		}

		fwint := firewall2.(FirewallSSOInt)

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
