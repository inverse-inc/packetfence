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
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Pf"`
	PfconfigHashNS string `val:"general"`
	Domain         string `json:"domain"`
	DNS_Servers    string `json:"dnsservers"`
	Timezone       string `json:"timezone"`
	Hostname       string `json:"hostname"`
	DHCP_Servers   string `json:"dhcpservers"`
}

type FirewallSSO struct {
	PfconfigMethod string   `val:"hash_element"`
	PfconfigNS     string   `val:"config::Firewall_SSO"`
	PfconfigHashNS string   `val:"-"`
	Type           string   `json:"type"`
	NacName        string   `json:"nac_name"`
	Password       string   `json:"password"`
	Roles          []string `json:"categories"`
	Networks       []string `json:"networks"`
	Port           string   `json:"port"`
	CacheUpdates   string   `json:"cache_updates"`
}
