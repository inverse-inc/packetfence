package libfirewallsso

import (
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"reflect"
)

// A factory for FirewallSSO
type Factory struct {
	typeRegistry map[string]reflect.Type
}

// Create a new FirewallSSO factory containing all the valid types
func NewFactory() Factory {
	f := Factory{}
	f.typeRegistry = make(map[string]reflect.Type)
	f.typeRegistry["Iboss"] = reflect.TypeOf(&Iboss{}).Elem()
	f.typeRegistry["PaloAlto"] = reflect.TypeOf(&PaloAlto{}).Elem()
	return f
}

// Instantiate a new FirewallSSO given its configuration ID in PacketFence
// TODO: This currently calls FetchDecodeSocketStruct twice which generates 2 calls to pfconfig
//			 This should be reworked so that only 1 call is done and the same payload is used to determine the type and to create the struct
func (f *Factory) Instantiate(id string) FirewallSSOInt {
	firewall := FirewallSSO{}
	firewall.PfconfigHashNS = id
	pfconfigdriver.FetchDecodeSocketStruct(&firewall)
	or := reflect.New(f.typeRegistry[firewall.Type])
	or.Elem().FieldByName("PfconfigHashNS").SetString(id)
	firewall2 := or.Interface()
	pfconfigdriver.FetchDecodeSocket(&firewall2, or.Elem())
	return firewall2.(FirewallSSOInt)
}
