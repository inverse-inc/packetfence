package libfirewallsso

import (
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"reflect"
)

type FirewallSSOInt interface {
}

type FirewallSSO struct {
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Firewall_SSO"`
	PfconfigHashNS string `val:"-"`
	pfconfigdriver.TypedConfig
	Networks     []string `json:"networks"`
	CacheUpdates string   `json:"cache_updates"`
}

type RoleBasedFirewallSSO struct {
	Roles []string `json:"categories"`
}

type Iboss struct {
	FirewallSSO
	RoleBasedFirewallSSO
	NacName  string `json:"nac_name"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

type Factory struct {
	typeRegistry map[string]reflect.Type
}

func NewFactory() Factory {
	f := Factory{}
	f.typeRegistry = make(map[string]reflect.Type)
	f.typeRegistry["Iboss"] = reflect.TypeOf(&Iboss{}).Elem()
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
	return firewall2
}
