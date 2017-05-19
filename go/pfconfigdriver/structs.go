package pfconfigdriver

import (
	"context"
	"encoding/json"
	"net"
	"time"
)

// Interface for a pfconfig object. Not doing much now but it is there for future-proofing
type PfconfigObject interface {
	GetLoadedAt() time.Time
	SetLoadedAt(time.Time)
}

// A basic StructConfig that contains the loaded at time which ensures FetchDecodeSocketCache will refresh the struct when needed
// FetchDecodeSocket can be used by structs that don't include this one, but the pool uses FetchDecodeSocketCache so this struct should always be included in the pfconfig based structs
type StructConfig struct {
	PfconfigLoadedAt time.Time
}

// Set the loaded at of the struct
func (ps *StructConfig) SetLoadedAt(t time.Time) {
	ps.PfconfigLoadedAt = t
}

// Get the loaded at time of the struct
func (ps *StructConfig) GetLoadedAt() time.Time {
	return ps.PfconfigLoadedAt
}

// pfconfig replies with the «struct» nested in an element key of a hash
// ex: {"element":{"data1":"value1", "data2":"value2"}}
// The structs are built to receive the value of element, so in order to have 2 stage decoding, this serves as a receiver for the pfconfig payload which then gets decoded into the right type
type PfconfigElementResponse struct {
	Element *json.RawMessage
}

// To be combined with another struct in order to give it a Type attribute common in PF
type TypedConfig struct {
	Type string `json:"type"`
}

// Represents the pf.conf general section
type PfConfGeneral struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Pf"`
	PfconfigHashNS string `val:"general"`
	Domain         string `json:"domain"`
	Timezone       string `json:"timezone"`
	Hostname       string `json:"hostname"`
	DHCP_Servers   string `json:"dhcpservers"`
}

type PfConfFencing struct {
	StructConfig
	PfconfigMethod        string   `val:"hash_element"`
	PfconfigNS            string   `val:"config::Pf"`
	PfconfigHashNS        string   `val:"fencing"`
	WirelessIpsThreshold  string   `json:"wireless_ips_threshold"`
	InterceptionProxy     string   `json:"interception_proxy"`
	Detection             string   `json:"detection"`
	DetectionEngine       string   `json:"detection_engine"`
	WirelessIps           string   `json:"wireless_ips"`
	Range                 string   `json:"range"`
	InterceptionProxyPort string   `json:"interception_proxy_port"`
	Registration          string   `json:"registration"`
	Whitelist             string   `json:"whitelist"`
	ProxyPassthroughs     []string `json:"proxy_passthroughs"`
	Passthroughs          []string `json:"passthroughs"`
	Redirtimer            string   `json:"redirtimer"`
	WaitForRedirect       string   `json:"wait_for_redirect"`
	Passthrough           string   `json:"passthrough"`
}

type PfConfCaptivePortal struct {
	StructConfig
	PfconfigMethod          string   `val:"hash_element"`
	PfconfigNS              string   `val:"config::Pf"`
	PfconfigHashNS          string   `val:"captive_portal"`
	DetectionMecanismBypass string   `json:"detection_mecanism_bypass"`
	DetectionMecanismUrls   []string `json:"detection_mecanism_urls"`
	NetworkDetection        string   `json:"network_detection"`
	NetworkDetectionIP      string   `json:"network_detection_ip"`
	ImagePath               string   `json:"image_path"`
	LoadbalancersIP         string   `json:"loadbalancers_ip"`
	RequestTimeout          string   `json:"request_timeout"`
	SecureRedirect          string   `json:"secure_redirect"`
	StatusOnlyOnProduction  string   `json:"status_only_on_production"`
	WisprRedirection        string   `json:"wispr_redirection"`
}

type ManagementNetwork struct {
	StructConfig
	PfconfigMethod string `val:"element"`
	PfconfigNS     string `val:"interfaces::management_network"`
	Ip             string `json:"ip"`
	Vip            string `json:"vip"`
	Mask           string `json:"mask"`
	Int            string `json:"int"`
}

func (mn *ManagementNetwork) GetNetIP(ctx context.Context) (net.IP, *net.IPNet, error) {
	ip, ipnet, err := net.ParseCIDR(mn.Ip + "/" + mn.Mask)
	return ip, ipnet, err
}

// Used when fetching the sections from a pfconfig HASH namespace
// This will store the keys (section names) in the Keys attribute
// **DO NOT** use this directly through the resource pool as the pool is type based which means that all your structs pointing to different namespaces will point to the namespace that was used first
type PfconfigKeys struct {
	StructConfig
	PfconfigMethod string `val:"keys"`
	PfconfigNS     string `val:"-"`
	Keys           []string
}

type ListenInts struct {
	StructConfig
	PfconfigMethod string `val:"element"`
	PfconfigNS     string `val:"interfaces::listen_ints"`
	PfconfigArray  string `val:"yes"`
	Element        []string
}

type configStruct struct {
	Interfaces struct {
		ListenInts        ListenInts
		ManagementNetwork ManagementNetwork
	}
	PfConf struct {
		General       PfConfGeneral
		Fencing       PfConfFencing
		CaptivePortal PfConfCaptivePortal
	}
}

var Config configStruct

type PfNetwork struct {
	PfconfigMethod string `val:"keys"`
	PfconfigNS     string `val:"config::Network"`
	Keys           []string
}

type NetworkConf struct {
	PfconfigMethod       string `val:"hash_element"`
	PfconfigNS           string `val:"config::Network"`
	PfconfigHashNS       string `val:"-"`
	Dns                  string `json:"dns"`
	DhcpStart            string `json:"dhcp_start"`
	Gateway              string `json:"gateway"`
	DomainName           string `json:"domain-name"`
	NatEnabled           string `json:"nat_enabled"`
	DhcpMaxLeaseTime     string `json:"dhcp_max_lease_time"`
	Named                string `json:"named"`
	FakeMacEnabled       string `json:"fake_mac_enabled"`
	Dhcpd                string `json:"dhcpd"`
	DhcpEnd              string `json:"dhcp_end"`
	Type                 string `json:"type"`
	Netmask              string `json:"netmask"`
	DhcpDefaultLeaseTime string `json:"dhcp_default_lease_time"`
	NextHop              string `json:"next_hop"`
	SplitNetwork         string `json:"split_network"`
}

type PfRoles struct {
	PfconfigMethod string `val:"keys"`
	PfconfigNS     string `val:"config::Roles"`
	Keys           []string
}

type RolesConf struct {
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Roles"`
	PfconfigHashNS string `val:"-"`
	Notes          string `json:"notes"`
	MaxNodesPerPid string `json:"max_nodes_per_pid"`
}
