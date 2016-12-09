package pfconfigdriver

import (
	"encoding/json"
)

type PfconfigObject interface {
}

type PfconfigResponse struct {
	Element *json.RawMessage
}

type PfConfGeneral struct {
	PfconfigMetadata string `ns:"config::Pf;general" method:"hash_element" json:"-"`
	Domain           string `json:"domain"`
	DNS_Servers      string `json:"dnsservers"`
	Timezone         string `json:"timezone"`
	Hostname         string `json:"hostname"`
	DHCP_Servers     string `json:"dhcpservers"`
}
