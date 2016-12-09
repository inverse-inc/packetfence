package libfirewallsso

import (
	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"reflect"
)

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
	f.typeRegistry["Iboss"] = reflect.TypeOf(Iboss{})
	return f
}

func (f *Factory) Instantiate(id string) interface{} {
	firewall := FirewallSSO{}
	firewall.PfconfigHashNS = id
	pfconfigdriver.FetchDecodeSocket(&firewall, reflect.Value{})
	spew.Dump(firewall)
	or := reflect.New(f.typeRegistry[firewall.Type]).Elem()
	or.FieldByName("PfconfigHashNS").SetString(id)
	firewall2 := or.Interface()
	//firewall2.PfconfigHashNS = id
	pfconfigdriver.FetchDecodeSocket(&firewall2, or)
	spew.Dump(firewall2)
	return firewall2
}
