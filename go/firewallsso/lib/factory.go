package libfirewallsso

import (
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"reflect"
)

type Factory struct {
	typeRegistry map[string]reflect.Type
}

func NewFactory() Factory {
	f := Factory{}
	f.typeRegistry = make(map[string]reflect.Type)
	f.typeRegistry["Iboss"] = reflect.TypeOf(&Iboss{}).Elem()
	f.typeRegistry["PaloAlto"] = reflect.TypeOf(&PaloAlto{}).Elem()
	return f
}

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
