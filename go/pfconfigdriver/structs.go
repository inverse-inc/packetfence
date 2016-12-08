package pfconfigdriver

import (
	"encoding/json"
)

type PfconfigObject interface {
	PfconfigNamespace() string
	PfconfigMethod() string
}

type PfconfigResponse struct {
	Element *json.RawMessage
}

type PfConfGeneral struct {
	Domain       string `json:"domain"`
	DNS_Servers  string `json:"dnsservers"`
	Timezone     string `json:"timezone"`
	Hostname     string `json:"hostname"`
	DHCP_Servers string `json:"dhcpservers"`
}

func (c *PfConfGeneral) PfconfigMethod() string {
	return "hash_element"
}

func (c *PfConfGeneral) PfconfigNamespace() string {
	return "config::Pf;general"
}
