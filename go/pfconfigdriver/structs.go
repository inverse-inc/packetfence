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
	PfconfigLoadedAt           time.Time
	PfconfigHostnameOverlay    string `val:"no"`
	PfconfigClusterNameOverlay string `val:"no"`
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

type configStruct struct {
	Passthroughs struct {
		Registration PassthroughsConf
		Isolation    PassthroughsIsolationConf
	}
	Interfaces struct {
		ListenInts        ListenInts
		ManagementNetwork ManagementNetwork
	}
	PfConf struct {
		General       PfConfGeneral
		Fencing       PfConfFencing
		CaptivePortal PfConfCaptivePortal
		Webservices   PfConfWebservices
		Database      PfConfDatabase
	}
	AdminRoles AdminRoles
	Cluster    struct {
		HostsIp struct {
			PfconfigKeys
			PfconfigNS                 string `val:"resource::cluster_hosts_ip"`
			PfconfigClusterNameOverlay string `val:"yes"`
		}
	}
	UnifiedApiSystemUser UnifiedApiSystemUser
}

var Config configStruct

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
	WaitForRedirect       string   `json:"wait_for_redirect"`
	Passthrough           string   `json:"passthrough"`
}

type PfConfCaptivePortal struct {
	StructConfig
	PfconfigMethod               string   `val:"hash_element"`
	PfconfigNS                   string   `val:"config::Pf"`
	PfconfigHashNS               string   `val:"captive_portal"`
	DetectionMecanismBypass      string   `json:"detection_mecanism_bypass"`
	DetectionMecanismUrls        []string `json:"detection_mecanism_urls"`
	NetworkDetection             string   `json:"network_detection"`
	NetworkDetectionIP           string   `json:"network_detection_ip"`
	NetworkDetectionInitialDelay int      `json:"network_detection_initial_delay"`
	NetworkDetectionRetryDelay   int      `json:"network_detection_retry_delay"`
	NetworkRedirectDelay         int      `json:"network_redirect_delay"`
	ImagePath                    string   `json:"image_path"`
	LoadbalancersIP              string   `json:"loadbalancers_ip"`
	RequestTimeout               string   `json:"request_timeout"`
	SecureRedirect               string   `json:"secure_redirect"`
	StatusOnlyOnProduction       string   `json:"status_only_on_production"`
	WisprRedirection             string   `json:"wispr_redirection"`
}

type PfConfWebservices struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Pf"`
	PfconfigHashNS string `val:"webservices"`
	Pass           string `json:"pass"`
	Proto          string `json:"proto"`
	User           string `json:"user"`
	Port           string `json:"port"`
	AAAPort        string `json:"aaa_port"`
	UnifiedAPIPort string `json:"unifiedapi_port"`
	Host           string `json:"host"`
}

type UnifiedApiSystemUser struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"resource::unified_api_system_user"`
	User           string `json:"user"`
	Pass           string `json:"pass"`
}

type PfConfDatabase struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Pf"`
	PfconfigHashNS string `val:"database"`
	User           string `json:"user"`
	Pass           string `json:"pass"`
	Host           string `json:"host"`
	Port           string `json:"port"`
	Db             string `json:"db"`
}

type ManagementNetwork struct {
	StructConfig
	PfconfigHostnameOverlay string `val:"yes"`
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"interfaces::management_network"`
	Ip                      string `json:"ip"`
	Vip                     string `json:"vip"`
	Mask                    string `json:"mask"`
	Int                     string `json:"int"`
}

func (mn *ManagementNetwork) GetNetIP(ctx context.Context) (net.IP, *net.IPNet, error) {
	ip, ipnet, err := net.ParseCIDR(mn.Ip + "/" + mn.Mask)
	return ip, ipnet, err
}

type AdminRole struct {
	Description string          `json:"description"`
	Actions     map[string]bool `json:"ACTIONS"`
}

type AdminRoles struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"config::AdminRoles"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string]AdminRole
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

type PfconfigKeysInt interface {
	GetKeys() *[]string
}

func (pk *PfconfigKeys) GetKeys() *[]string {
	return &(pk.Keys)
}

type ListenInts struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"interfaces::listen_ints"`
	PfconfigArray           string `val:"yes"`
	PfconfigHostnameOverlay string `val:"yes"`
	Element                 []string
}

type PfClusterIp struct {
	StructConfig
	PfconfigMethod             string `val:"hash_element"`
	PfconfigNS                 string `val:"resource::cluster_hosts_ip"`
	PfconfigClusterNameOverlay string `val:"yes"`
	PfconfigHashNS             string `val:"-"`
	Ip                         string `json:"ip"`
}

type PfNetwork struct {
	StructConfig
	PfconfigMethod          string `val:"keys"`
	PfconfigNS              string `val:"config::Network"`
	PfconfigHostnameOverlay string `val:"yes"`
	Keys                    []string
}

type NetworkConf struct {
	StructConfig
	PfconfigMethod          string `val:"hash_element"`
	PfconfigNS              string `val:"config::Network"`
	PfconfigHostnameOverlay string `val:"yes"`
	PfconfigHashNS          string `val:"-"`
	Dns                     string `json:"dns"`
	DhcpStart               string `json:"dhcp_start"`
	Gateway                 string `json:"gateway"`
	DomainName              string `json:"domain-name"`
	NatEnabled              string `json:"nat_enabled"`
	DhcpMaxLeaseTime        string `json:"dhcp_max_lease_time"`
	Named                   string `json:"named"`
	FakeMacEnabled          string `json:"fake_mac_enabled"`
	Dhcpd                   string `json:"dhcpd"`
	DhcpEnd                 string `json:"dhcp_end"`
	Type                    string `json:"type"`
	Netmask                 string `json:"netmask"`
	DhcpDefaultLeaseTime    string `json:"dhcp_default_lease_time"`
	NextHop                 string `json:"next_hop"`
	SplitNetwork            string `json:"split_network"`
	RegNetwork              string `json:"reg_network"`
}

type Interface struct {
	InterfaceName string `json:"int"`
	Mask          string `json:"mask"`
	Ip            string `json:"ip"`
	Cidr          string `json:"cidr"`
}

type RessourseNetworkConf struct {
	StructConfig
	PfconfigMethod       string    `val:"hash_element"`
	PfconfigNS           string    `val:"resource::network_config"`
	PfconfigHashNS       string    `val:"-"`
	Dns                  string    `json:"dns"`
	DhcpStart            string    `json:"dhcp_start"`
	Gateway              string    `json:"gateway"`
	DomainName           string    `json:"domain-name"`
	NatEnabled           string    `json:"nat_enabled"`
	DhcpMaxLeaseTime     string    `json:"dhcp_max_lease_time"`
	Named                string    `json:"named"`
	FakeMacEnabled       string    `json:"fake_mac_enabled"`
	Dhcpd                string    `json:"dhcpd"`
	DhcpEnd              string    `json:"dhcp_end"`
	Type                 string    `json:"type"`
	Netmask              string    `json:"netmask"`
	DhcpDefaultLeaseTime string    `json:"dhcp_default_lease_time"`
	NextHop              string    `json:"next_hop"`
	SplitNetwork         string    `json:"split_network"`
	RegNetwork           string    `json:"reg_network"`
	Dnsvip               string    `json:"dns_vip"`
	ClusterIPs           string    `json:"cluster_ips"`
	IpReserved           string    `json:"ip_reserved"`
	IpAssigned           string    `json:"ip_assigned"`
	Interface            Interface `json:"interface"`
}

type PfRoles struct {
	StructConfig
	PfconfigMethod string `val:"keys"`
	PfconfigNS     string `val:"config::Roles"`
	Keys           []string
}

type RolesConf struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Roles"`
	PfconfigHashNS string `val:"-"`
	Notes          string `json:"notes"`
	MaxNodesPerPid string `json:"max_nodes_per_pid"`
}

type ClusterName struct {
	StructConfig
	PfconfigMethod          string `val:"hash_element"`
	PfconfigNS              string `val:"resource::clusters_hostname_map"`
	PfconfigHashNS          string `val:"-"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 string
}

type NetInterface struct {
	StructConfig
	PfconfigHostnameOverlay string `val:"yes"`
	PfconfigMethod          string `val:"hash_element"`
	PfconfigNS              string `val:"-"`
	PfconfigHashNS          string `val:"-"`
	Ip                      string `json:"ip"`
	Type                    string `json:"type"`
	Enforcement             string `json:"enforcement"`
	Mask                    string `json:"mask"`
}

type PassthroughsConf struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"resource::passthroughs"`
	Wildcard       map[string][]string
	Normal         map[string][]string
}

type PassthroughsIsolationConf struct {
	PassthroughsConf
	PfconfigNS string `val:"resource::isolation_passthroughs"`
}

type AuthenticationSourceEduroam struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"resource::authentication_sources_eduroam"`
	PfconfigHashNS string `val:"-"`
	Description    string `json:"description"`
	RadiusSecret   string `json:"radius_secret"`
	Server1Address string `json:"server1_address"`
	Server2Address string `json:"server2_address"`
	Monitor        string `json:"monitor"`
	Type           string `json:"type"`
}

type AuthenticationSourceRadius struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"resource::authentication_sources_radius"`
	PfconfigHashNS string `val:"-"`
	Description    string `json:"description"`
	Secret         string `json:"secret"`
	Port           string `json:"port"`
	Host           string `json:"host"`
	Timeout        string `json:"timeout"`
	Monitor        string `json:"monitor"`
	Type           string `json:"type"`
}

type AuthenticationSourceLdap struct {
	StructConfig
	PfconfigMethod    string `val:"hash_element"`
	PfconfigNS        string `val:"resource::authentication_sources_ldap"`
	PfconfigHashNS    string `val:"-"`
	Description       string `json:"description"`
	Password          string `json:"password"`
	Port              string `json:"port"`
	Host              string `json:"host"`
	ReadTimeout       string `json:"read_timeout"`
	WriteTimeout      string `json:"write_timeout"`
	BaseDN            string `json:"basedn"`
	Scope             string `json:"scope"`
	EmailAttribute    string `json:"email_attribute"`
	UserNameAttribute string `json:"usernameattribute"`
	BindDN            string `json:"binddn"`
	Encryption        string `json:"encryption"`
	Monitor           string `json:"monitor"`
	Type              string `json:"type"`
}

type PfStats struct {
	StructConfig
	PfconfigMethod          string `val:"hash_element"`
	PfconfigHashNS          string `val:"-"`
	PfconfigNS              string `val:"config::Stats"`
	PfconfigHostnameOverlay string `val:"yes"`
	File                    string `json:"file"`
	Match                   string `json:"match"`
	Type                    string `json:"type"`
	StatsdType              string `json:"statsd_type"`
	StatsdNS                string `json:"statsd_ns"`
	MySQLQuery              string `json:"mysql_query"`
	Interval                string `json:"interval"`
	Randomize               string `json:"randomize"`
	Host                    string `json:"host"`
	ApiMethod               string `json:"api_method"`
	ApiPayload              string `json:"api_payload"`
	ApiPath                 string `json:"api_path"`
	ApiCompile              string `json:"api_compile"`
}

type ClusterSummary struct {
	StructConfig
	ClusterEnabled   int `json:"cluster_enabled"`
	MultiZoneEnabled int `json:"multi_zone_enabled"`
}
