package pfconfigdriver

import (
	"encoding/json"
	"reflect"
)

type PfconfigObject interface {
}

type PfconfigElementResponse struct {
	Element *json.RawMessage
}

type TypedConfig struct {
	Type string `json:"type"`
}

type PfConfGeneral struct {
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Pf"`
	PfconfigHashNS string `val:"general"`
	Domain         string `json:"domain"`
	DNS_Servers    string `json:"dnsservers"`
	Timezone       string `json:"timezone"`
	Hostname       string `json:"hostname"`
	DHCP_Servers   string `json:"dhcpservers"`
}

type ConfigSections struct {
	PfconfigMethod string `val:"keys"`
	PfconfigNS     string `val:"-"`
	Keys           []string
}

func (cs *ConfigSections) reflect() reflect.Value {
	return reflect.ValueOf(cs).Elem()
}
