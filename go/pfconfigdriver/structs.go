package pfconfigdriver

import (
	"encoding/json"
)

type PfconfigObject interface {
}

type PfconfigResponse struct {
	Element *json.RawMessage
}

//PfconfigMetadata string `ns:"config::Pf;general" method:"hash_element" json:"-"`

type PfConfGeneral struct {
	PfconfigMethod bool   `method:"hash_element"`
	PfconfigNS     bool   `ns:"config::Pf"`
	PfconfigHashNS bool   `ns:"general"`
	Domain         string `json:"domain"`
	DNS_Servers    string `json:"dnsservers"`
	Timezone       string `json:"timezone"`
	Hostname       string `json:"hostname"`
	DHCP_Servers   string `json:"dhcpservers"`
}
