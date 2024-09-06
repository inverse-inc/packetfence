package pfconfigdriver

import (
	"context"
	"encoding/json"
	"net"
	"time"

	"github.com/inverse-inc/go-utils/sharedutils"
)

// Interface for a pfconfig object. Not doing much now but it is there for future-proofing
type PfconfigObject interface {
	GetLoadedAt() time.Time
	SetLoadedAt(time.Time)
	GetLastTouchCache() float64
}

// A basic StructConfig that contains the loaded at time which ensures FetchDecodeSocketCache will refresh the struct when needed
// FetchDecodeSocket can be used by structs that don't include this one, but the pool uses FetchDecodeSocketCache so this struct should always be included in the pfconfig based structs
type StructConfig struct {
	LastTouchCache             float64 `json:"last_touch_cache"`
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

func (ps *StructConfig) GetLastTouchCache() float64 {
	return ps.LastTouchCache
}

// pfconfig replies with the «struct» nested in an element key of a hash
// ex: {"element":{"data1":"value1", "data2":"value2"}}
// The structs are built to receive the value of element, so in order to have 2 stage decoding, this serves as a receiver for the pfconfig payload which then gets decoded into the right type
type PfconfigElementResponse struct {
	LastTouchCache float64 `json:"last_touch_cache"`
	Element        *json.RawMessage
}

// To be combined with another struct in order to give it a Type attribute common in PF
type TypedConfig struct {
	Type string `json:"type"`
}

type HostsIp struct {
	PfconfigKeys
	PfconfigNS                 string `val:"resource::cluster_hosts_ip"`
	PfconfigClusterNameOverlay string `val:"yes"`
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

type PfConfPorts struct {
	StructConfig
	PfconfigMethod       string `val:"hash_element"`
	PfconfigNS           string `val:"config::Pf"`
	PfconfigHashNS       string `val:"ports"`
	Admin                string `json:"admin"`
	Soap                 string `json:"soap"`
	AAA                  string `json:"aaa"`
	HttpdPortalModStatus string `json:"httpd_portal_modstatus"`
	UnifiedAPI           string `json:"unifiedapi"`
	PFAcctNetflow        string `json:"pfacct_netflow"`
}

type PfConfPfconnector struct {
	StructConfig
	PfconfigMethod        string `val:"hash_element"`
	PfconfigNS            string `val:"config::Pf"`
	PfconfigHashNS        string `val:"pfconnector"`
	RedisServer           string `json:"redis_server"`
	RedisTunnelsNamespace string `json:"redis_tunnels_namespace"`
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
	IpAddress                    string   `json:"ip_address"`
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
	RateLimiting                 string   `json:"rate_limiting"`
	RateLimitingThreshold        string   `json:"rate_limiting_threshold"`
	OtherDomainNames             []string `json:"other_domain_names"`
}

type PfConfServices struct {
	StructConfig
	PfconfigMethod       string `val:"hash_element"`
	PfconfigNS           string `val:"config::Pf"`
	PfconfigHashNS       string `val:"services"`
	ApiFrontend          string `json:"api-frontend"`
	GaleraAutofix        string `json:"galera-autofix"`
	FingerbankCollector  string `json:"fingerbank-collector"`
	HaproxyAdmin         string `json:"haproxy-admin"`
	HaproxyDB            string `json:"haproxy-db"`
	HaproxyPortal        string `json:"haproxy-portal"`
	HttpdAAA             string `json:"httpd_aaa"`
	HttpdAdmin           string `json:"httpd_admin"`
	HttpdAdminDispatcher string `json:"httpd_admin_dispatcher"`
	HttpdDispatcher      string `json:"httpd_dispatcher"`
	HttpdPortal          string `json:"httpd_portal"`
	HttpdWebservices     string `json:"httpd_webservices"`
	Iptables             string `json:"iptables"`
	Keepalived           string `json:"keepalived"`
	Netdata              string `json:"netdata"`
	NetFlowAddress       string `json:"netflow_address"`
	MysqlProbe           string `json:"mysql-probe"`
	Pfacct               string `json:"pfacct"`
	Pfdhcp               string `json:"pfdhcp"`
	Pfdhcplistener       string `json:"pfdhcplistener"`
	Pfdns                string `json:"pfdns"`
	Pffilter             string `json:"pffilter"`
	Pfipset              string `json:"pfipset"`
	Pfcron               string `json:"pfcron"`
	PfperlAPI            string `json:"pfperl-api"`
	PfPKI                string `json:"pfpki"`
	Pfqueue              string `json:"pfqueue"`
	PfSSO                string `json:"pfsso"`
	Pfstats              string `json:"pfstats"`
	Radiusd              string `json:"radiusd"`
	RadiusdAcct          string `json:"radiusd_acct"`
	RadiusdAuth          string `json:"radiusd_auth"`
	Radsniff             string `json:"radsniff"`
	RedisCache           string `json:"redis_cache"`
	RedisNtlmCache       string `json:"redis_ntlm_cache"`
	RedisQueue           string `json:"redis_queue"`
	Snmptrapd            string `json:"snmptrapd"`
	TC                   string `json:"tc"`
	TrackingConfig       string `json:"tracking-config"`
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
	AAAHost        string `json:"aaa_host"`
	AAAPort        string `json:"aaa_port"`
	AAAProto       string `json:"aaa_proto"`
	UnifiedAPIHost string `json:"unifiedapi_host"`
	UnifiedAPIPort string `json:"unifiedapi_port"`
	Host           string `json:"host"`
}

type UnifiedApiSystemUser struct {
	StructConfig
	PfconfigMethod string `val:"element"`
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
	Response       struct {
		Keys           []string
		LastTouchCache float64
	}
}

type PfconfigKeysInt interface {
	GetKeys() *[]string
	GetResponse() interface{}
	SetKeysFromResponse()
}

func (pk *PfconfigKeys) SetKeysFromResponse() {
	pk.Keys = pk.Response.Keys
}

func (pk *PfconfigKeys) GetKeys() *[]string {
	return &(pk.Keys)
}

func (pk *PfconfigKeys) GetResponse() interface{} {
	return &pk.Response
}

type ListenInts struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"interfaces::listen_ints"`
	PfconfigArray           string `val:"yes"`
	PfconfigHostnameOverlay string `val:"yes"`
	Element                 []string
}

type DHCPInts struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"interfaces::dhcp_ints"`
	PfconfigArray           string `val:"yes"`
	PfconfigHostnameOverlay string `val:"yes"`
	Element                 []interface{}
}

type DNSInts struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"interfaces::dns_ints"`
	PfconfigArray           string `val:"yes"`
	PfconfigHostnameOverlay string `val:"yes"`
	Element                 []interface{}
}

type RADIUSInts struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"interfaces::radius_ints"`
	PfconfigArray           string `val:"yes"`
	PfconfigHostnameOverlay string `val:"yes"`
	Element                 []interface{}
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
	PfconfigMethod           string `val:"hash_element"`
	PfconfigNS               string `val:"config::Network"`
	PfconfigHostnameOverlay  string `val:"yes"`
	PfconfigHashNS           string `val:"-"`
	Dns                      string `json:"dns"`
	DhcpStart                string `json:"dhcp_start"`
	Gateway                  string `json:"gateway"`
	DomainName               string `json:"domain-name"`
	NatEnabled               string `json:"nat_enabled"`
	DhcpMaxLeaseTime         string `json:"dhcp_max_lease_time"`
	Named                    string `json:"named"`
	FakeMacEnabled           string `json:"fake_mac_enabled"`
	Dhcpd                    string `json:"dhcpd"`
	DhcpEnd                  string `json:"dhcp_end"`
	Type                     string `json:"type"`
	Netmask                  string `json:"netmask"`
	DhcpDefaultLeaseTime     string `json:"dhcp_default_lease_time"`
	NextHop                  string `json:"next_hop"`
	SplitNetwork             string `json:"split_network"`
	RegNetwork               string `json:"reg_network"`
	PortalFQDN               string `json:"portal_fqdn"`
	Algorithm                string `json:"algorithm"`
	PoolBackend              string `json:"pool_backend"`
	NetflowAccountingEnabled string `json:"netflow_accounting_enabled"`
	DhcpReplyIp              string `json:"dhcp_reply_ip"`
}

type Interface struct {
	InterfaceName string `json:"int"`
	Mask          string `json:"mask"`
	Ip            string `json:"ip"`
	Cidr          string `json:"cidr"`
}

type RessourseNetworkConf struct {
	StructConfig
	PfconfigMethod           string    `val:"hash_element"`
	PfconfigNS               string    `val:"resource::network_config"`
	PfconfigHostnameOverlay  string    `val:"yes"`
	PfconfigHashNS           string    `val:"-"`
	Dns                      string    `json:"dns"`
	DhcpStart                string    `json:"dhcp_start"`
	Gateway                  string    `json:"gateway"`
	DomainName               string    `json:"domain-name"`
	NatEnabled               string    `json:"nat_enabled"`
	DhcpMaxLeaseTime         string    `json:"dhcp_max_lease_time"`
	Named                    string    `json:"named"`
	FakeMacEnabled           string    `json:"fake_mac_enabled"`
	Dhcpd                    string    `json:"dhcpd"`
	DhcpEnd                  string    `json:"dhcp_end"`
	Type                     string    `json:"type"`
	Netmask                  string    `json:"netmask"`
	DhcpDefaultLeaseTime     string    `json:"dhcp_default_lease_time"`
	NextHop                  string    `json:"next_hop"`
	SplitNetwork             string    `json:"split_network"`
	RegNetwork               string    `json:"reg_network"`
	Dnsvip                   string    `json:"dns_vip"`
	ClusterIPs               string    `json:"cluster_ips"`
	IpReserved               string    `json:"ip_reserved"`
	IpAssigned               string    `json:"ip_assigned"`
	Interface                Interface `json:"interface"`
	PortalFQDN               string    `json:"portal_fqdn"`
	PoolBackend              string    `json:"pool_backend"`
	Algorithm                string    `json:"algorithm"`
	NetflowAccountingEnabled string    `json:"netflow_accounting_enabled"`
	NatDNS                   string    `json:"nat_dns"`
	ForceGatewayVIP          string    `json:"force_gateway_vip"`
	DhcpReplyIp              string    `json:"dhcp_reply_ip"`
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

type RolesChildren struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"resource::roles_children"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string][]string
}

type ClusterName struct {
	StructConfig
	PfconfigMethod          string `val:"hash_element"`
	PfconfigNS              string `val:"resource::clusters_hostname_map"`
	PfconfigHashNS          string `val:"-"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 string
}

type LocalSecret struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"resource::local_secret"`
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
	PfconfigMethod string `val:"element"`
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
	Server1Port    string `json:"server1_port"`
	Server2Port    string `json:"server2_port"`
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
	PfconfigMethod    string   `val:"hash_element"`
	PfconfigNS        string   `val:"resource::authentication_sources_ldap"`
	PfconfigHashNS    string   `val:"-"`
	Description       string   `json:"description"`
	Password          string   `json:"password"`
	Port              string   `json:"port"`
	Host              []string `json:"host"`
	ReadTimeout       string   `json:"read_timeout"`
	WriteTimeout      string   `json:"write_timeout"`
	BaseDN            string   `json:"basedn"`
	Scope             string   `json:"scope"`
	EmailAttribute    string   `json:"email_attribute"`
	UserNameAttribute string   `json:"usernameattribute"`
	UseConnector      bool     `json:"use_connector"`
	BindDN            string   `json:"binddn"`
	Encryption        string   `json:"encryption"`
	Monitor           string   `json:"monitor"`
	Type              string   `json:"type"`
}

func (t *AuthenticationSourceLdap) UnmarshalJSON(data []byte) error {
	var dataGeneric map[string]interface{}

	if err := json.Unmarshal(data, &dataGeneric); err != nil {
		return err
	}

	if use_connector, found := dataGeneric["use_connector"]; found {
		if str, ok := use_connector.(string); ok {
			dataGeneric["use_connector"] = sharedutils.IsEnabled(str)
		} else {
			dataGeneric["use_connector"] = false
		}
	} else {
		dataGeneric["use_connector"] = false
	}

	// Re-marshal after fixing the data
	newData, ok := json.Marshal(dataGeneric)
	if ok != nil {
		return ok
	}

	// Without new type the same UnmarshalJSON will be called recursively
	type ldap2 AuthenticationSourceLdap
	return json.Unmarshal(newData, (*ldap2)(t))
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
	Management              string `json:"management"`
}

type ClusterSummary struct {
	StructConfig
	ClusterEnabled   int `json:"cluster_enabled"`
	MultiZoneEnabled int `json:"multi_zone_enabled"`
}

type PfConfAdvanced struct {
	StructConfig
	PfconfigMethod                   string      `val:"hash_element"`
	PfconfigNS                       string      `val:"config::Pf"`
	PfconfigHashNS                   string      `val:"advanced"`
	HashingCost                      string      `json:"hashing_cost"`
	ScanOnAccounting                 string      `json:"scan_on_accounting"`
	PffilterProcesses                string      `json:"pffilter_processes"`
	UpdateIplogWithAccounting        string      `json:"update_iplog_with_accounting"`
	AdminCspSecurityHeaders          string      `json:"admin_csp_security_headers"`
	Multihost                        string      `json:"multihost"`
	SsoOnAccessReevaluation          string      `json:"sso_on_access_reevaluation"`
	DisablePfDomainAuth              string      `json:"disable_pf_domain_auth"`
	TimingStatsLevel                 string      `json:"timing_stats_level"`
	SsoOnDhcp                        string      `json:"sso_on_dhcp"`
	Language                         string      `json:"language"`
	StatsdListenPort                 string      `json:"statsd_listen_port"`
	SsoOnAccounting                  string      `json:"sso_on_accounting"`
	LocationlogCloseOnAccountingStop string      `json:"locationlog_close_on_accounting_stop"`
	PortalCspSecurityHeaders         string      `json:"portal_csp_security_headers"`
	HashPasswords                    string      `json:"hash_passwords"`
	SourceToSendSmsWhenCreatingUsers string      `json:"source_to_send_sms_when_creating_users"`
	ActiveDirectoryOsJoinCheckBypass string      `json:"active_directory_os_join_check_bypass"`
	PfperlApiTimeout                 string      `json:"pfperl_api_timeout"`
	LdapAttributes                   []string    `json:"ldap_attributes"`
	ApiInactivityTimeout             int         `json:"api_inactivity_timeout"`
	ApiMaxExpiration                 int         `json:"api_max_expiration"`
	NetFlowOnAllNetworks             string      `json:"netflow_on_all_networks"`
	AccountingTimebucketSize         int         `json:"accounting_timebucket_size"`
	ZeroTrustNetworkStartingIP       string      `json:"zero_trust_network_starting_ip"`
	ZeroTrustNetworkNetmask          json.Number `json:"zero_trust_network_netmask"`
}

type PfConfDns struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Pf"`
	PfconfigHashNS string `val:"dns_configuration"`
	RecordDNS      string `json:"record_dns_in_sql"`
}

type PfConfParking struct {
	StructConfig
	PfconfigMethod          string `val:"hash_element"`
	PfconfigNS              string `val:"config::Pf"`
	PfconfigHashNS          string `val:"parking"`
	LeaseLength             string `json:"lease_length"`
	Threshold               string `json:"threshold"`
	PlaceInDhcpParkingGroup string `json:"place_in_dhcp_parking_group"`
	ShowParkingPortal       string `json:"show_parking_portal"`
}

type PfConfAlerting struct {
	StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Pf"`
	PfconfigHashNS string `val:"alerting"`
	EmailAddr      string `json:"emailaddr"`
	FromAddr       string `json:"fromaddr"`
	SMTPPassword   string `json:"smtp_password"`
	SMTPEncryption string `json:"smtp_encryption"`
	SubjectPrefic  string `json:"subjectprefix"`
	SMTPUsername   string `json:"smtp_username"`
	SMTPTimeout    string `json:"smtp_timeout"`
	SMTPPort       int    `json:"smtp_port"`
	SMTPVerifySSL  string `json:"smtp_verifyssl"`
	SMTPServer     string `json:"smtpserver"`
}

type PfConfActiveActive struct {
	StructConfig
	PfconfigMethod            string `val:"hash_element"`
	PfconfigNS                string `val:"config::Pf"`
	PfconfigHashNS            string `val:"active_active"`
	GaleraReplicationUsername string `json:"galera_replication_username"`
	GaleraReplicationPassword string `json:"galera_replication_password"`
}

type AllClusterServers struct {
	StructConfig
	PfconfigMethod string `val:"element"`
	PfconfigNS     string `val:"resource::all_cluster_servers"`
	PfconfigArray  string `val:"yes"`
	Element        []ClusterServer
}

type ClusterServer struct {
	ManagementIp string `json:"management_ip"`
	Host         string `json:"host"`
}

type AllClusterServersRaw struct {
	StructConfig
	PfconfigMethod string `val:"element"`
	PfconfigNS     string `val:"resource::all_cluster_servers"`
	PfconfigArray  string `val:"yes"`
	Element        []interface{}
}

type SyslogFiles struct {
	StructConfig
	PfconfigMethod string `val:"element"`
	PfconfigNS     string `val:"resource::syslog_files"`
	PfconfigArray  string `val:"yes"`
	Element        []struct {
		Description string   `json:"description"`
		Name        string   `json:"name"`
		Conditions  []string `json:"conditions"`
	}
}

type PfConfRadiusConfiguration struct {
	StructConfig
	PfconfigMethod                     string   `val:"hash_element"`
	PfconfigNS                         string   `val:"config::Pf"`
	PfconfigHashNS                     string   `val:"radius_configuration"`
	RecordAccountingInSQL              string   `json:"record_accounting_in_sql"`
	FilterInPacketfenceAuthorize       string   `json:"filter_in_packetfence_authorize"`
	FilterInPacketfencePreProxy        string   `json:"filter_in_packetfence_pre_proxy"`
	FilterInPacketfencePostProxy       string   `json:"filter_in_packetfence_post_proxy"`
	FilterInPacketfencePreAcct         string   `json:"filter_in_packetfence_preacct"`
	FilterInPacketfenceAccounting      string   `json:"filter_in_packetfence_accounting"`
	FilterInPacketfenceTunnelAuthorize string   `json:"filter_in_packetfence-tunnel_authorize"`
	FilterInEduroamAuthorize           string   `json:"filter_in_eduroam_authorize"`
	FilterInEduroamPreProxy            string   `json:"filter_in_eduroam_pre_proxy"`
	FilterInEduroamPostProxy           string   `json:"filter_in_eduroam_post_proxy"`
	FilterInEduroamPreAcct             string   `json:"filter_in_eduroam_preacct"`
	NTLMRedisCache                     string   `json:"ntlm_redis_cache"`
	RadiusAttributes                   []string `json:"radius_attributes"`
	UsernameAttributes                 []string `json:"username_attributes"`
	ForwardKeyBalanced                 string   `json:"forward_key_balanced"`
	ProcessBandwidthAccounting         string   `json:"process_bandwidth_accounting"`
	PfacctWorkers                      string   `json:"pfacct_workers"`
	PfacctWorkQueueSize                string   `json:"pfacct_work_queue_size"`
}

type PfQueueConfig struct {
	StructConfig
	PfconfigMethod string                `val:"hash_element"`
	PfconfigNS     string                `val:"config::Pfqueue"`
	PfQueue        PfQueue               `json:"pfqueue"`
	Queues         []Queue               `json:"queues"`
	Consumer       Consumer              `json:"consumer"`
	QueueConfig    map[string]QueueEntry `json:"queue_config"`
	Producer       Producer              `json:"producer"`
}

type PfQueue struct {
	Workers    int `json:"workers"`
	TaskJitter int `json:"task_jitter"`
	MaxTasks   int `json:"max_tasks"`
}

type Queue struct {
	Weight   int    `json:"weight"`
	RealName string `json:"real_name"`
	Name     string `json:"name"`
	Hashed   string `json:"hashed,omitempty"`
	Workers  int    `json:"workers"`
}

type RedisArgs struct {
	Reconnect int    `json:"reconnect"`
	Every     int    `json:"every"`
	Server    string `json:"server"`
}

type Consumer struct {
	RedisArgs RedisArgs `json:"redis_args"`
}

type QueueEntry struct {
	Weight  int    `json:"weight"`
	Hashed  string `json:"hashed"`
	Workers int    `json:"workers"`
}

type Producer struct {
	RedisServer string `json:"redis_server"`
}

type Certificate struct {
	StructConfig
	Cert               string `json:"cert"`
	Default            string `json:"default"`
	Key                string `json:"key"`
	Ca                 string `json:"ca"`
	Intermediate       string `json:"intermediate"`
	PrivateKeyPassword string `json:"private_key_password"`
}

type Fast struct {
	StructConfig
	PacOpaqueKey      string `json:"pac_opaque_key"`
	AuthorityIdentity string `json:"authority_identity"`
	TLS               string `json:"tls"`
}

type OCSP struct {
	StructConfig
	OCSPSoftfail        string `json:"ocsp_softfail"`
	OCSPTimeout         string `json:"ocsp_timeout"`
	OCSPUseNonce        string `json:"ocsp_use_nonce"`
	OCSPEnable          string `json:"ocsp_enable"`
	OCSPOverrideCertURL string `json:"ocsp_override_cert_url"`
	OCSPURL             string `json:"ocsp_url"`
}

type TLS struct {
	StructConfig
	CertificateProfile Certificate `json:"certificate_profile"`
	DhFile             string      `json:"dh_file"`
	CAPath             string      `json:"ca_path"`
	EcdhCurve          string      `json:"ecdh_curve"`
	CipherList         string      `json:"cipher_list"`
	OCSP               OCSP        `json:"ocsp"`
}

type EAP struct {
	StructConfig
	DefaultEAPType             string         `json:"default_eap_type"`
	TLS                        map[string]TLS `json:"tls"`
	TTLSProfile                string         `json:"ttls_tlsprofile"`
	TLSProfile                 string         `json:"tls_tlsprofile"`
	TimerExpire                string         `json:"timer_expire"`
	CiscoAccountingUsernameBug string         `json:"cisco_accounting_username_bug"`
	PEAPProfile                string         `json:"peap_tlsprofile"`
	EAPAuthenticationTypes     []string       `json:"eap_authentication_types"`
	MaxSessions                string         `json:"max_sessions"`
	FastConfig                 Fast           `json:"fast_config"`
	IgnoreUnknownEAPTypes      string         `json:"ignore_unknown_eap_types"`
}

type EAPConfiguration struct {
	StructConfig
	PfconfigMethod          string `val:"hash_element"`
	PfconfigNS              string `val:"resource::eap_config"`
	PfconfigDecodeInElement string `val:"yes"`
	PfconfigArray           string `val:"yes"`
	PfconfigHostnameOverlay string `val:"yes"`
	Element                 map[string]EAP
}

type Cron struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"config::Cron"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string]interface{}
}

type NtlmRedisCachedDomains struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"resource::NtlmRedisCachedDomains"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 []string
}

type Domain struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"config::Domain"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string]interface{}
}

type FleetDM struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"config::FleetDM"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string]interface{}
}

type Cloud struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"config::Cloud"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string]interface{}
}

type FQDN struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"resource::fqdn"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 string
}

type PfConfServicesURL struct {
	StructConfig
	PfconfigMethod        string `val:"hash_element"`
	PfconfigNS            string `val:"config::Pf"`
	PfconfigHashNS        string `val:"services_url"`
	HttpdPortal           string `json:"httpd_portal"`
	HttpdDispatcher       string `json:"httpd_dispatcher"`
	HttpdDispatcherStatic string `json:"httpd_dispatcher_static"`
	Pfpki                 string `json:"pfpki"`
	Pfipset               string `json:"pfipset"`
	Pfdhcp                string `json:"pfdhcp"`
	PfperlApi             string `json:"pfperl-api"`
	PfdnsDoh              string `json:"pfdns-doh"`
	Pfsso                 string `json:"pfsso"`
}

type PfConfAdminLogin struct {
	StructConfig
	PfconfigMethod        string `val:"hash_element"`
	PfconfigNS            string `val:"config::Pf"`
	PfconfigHashNS        string `val:"admin_login"`
	SSOAuthorizePath      string `json:"sso_authorize_path"`
	SSOBaseUrl            string `json:"sso_base_url"`
	SSOLoginPath          string `json:"sso_login_path"`
	SSOLoginText          string `json:"sso_login_text"`
	SSOStatus             string `json:"sso_status"`
	AllowUsernamePassword string `json:"allow_username_password"`
}

type Connectors struct {
	StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"config::Connector"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string]struct {
		Secret string `json:"secret"`
	}
}

type FingerbankSettingsUpstream struct {
	StructConfig
	PfconfigMethod    string      `val:"hash_element"`
	PfconfigNS        string      `val:"config::FingerbankSettings"`
	PfconfigHashNS    string      `val:"upstream"`
	ApiKey            string      `json:"api_key"`
	Host              string      `json:"host"`
	Port              json.Number `json:"port"`
	UseHttps          string      `json:"use_https"`
	DbPath            string      `json:"db_path"`
	SQLiteDbRetention string      `json:"sqlite_db_retention"`
}

type FingerbankSettingsCollector struct {
	StructConfig
	PfconfigMethod              string      `val:"hash_element"`
	PfconfigNS                  string      `val:"config::FingerbankSettings"`
	PfconfigHashNS              string      `val:"collector"`
	Host                        string      `json:"host"`
	Port                        json.Number `json:"port"`
	UseHttps                    string      `json:"use_https"`
	InactiveEndpointsExpiration json.Number `json:"inactive_endpoints_expiration"`
	ArpLookup                   string      `json:"arp_lookup"`
	QueryCacheTime              json.Number `json:"query_cache_time"`
	DbPersistenceInterval       json.Number `json:"db_persistence_interval"`
	ClusterResyncInterval       json.Number `json:"cluster_resync_interval"`
	NetworkBehaviorAnalysis     string      `json:"network_behavior_analysis"`
	AdditionalEnv               string      `json:"additional_env"`
}

type FingerbankSettingsQuery struct {
	StructConfig
	PfconfigMethod  string `val:"hash_element"`
	PfconfigNS      string `val:"config::FingerbankSettings"`
	PfconfigHashNS  string `val:"collector"`
	RecordUnmatched string `json:"record_unmatched"`
}

type FingerbankSettingsProxy struct {
	StructConfig
	PfconfigMethod string      `val:"hash_element"`
	PfconfigNS     string      `val:"config::FingerbankSettings"`
	PfconfigHashNS string      `val:"collector"`
	UseProxy       string      `json:"use_proxy"`
	Host           string      `json:"host"`
	Port           json.Number `json:"port"`
	VerifySsl      string      `json:"verify_ssl"`
}

type FingerbankSettings struct {
	StructConfig
	PfconfigMethod string `val:"element"`
	PfconfigNS     string `val:"config::FingerbankSettings"`
	PfconfigHashNS string `val:"collector"`
	Upstream       FingerbankSettingsUpstream
	Collector      FingerbankSettingsCollector
	Query          FingerbankSettingsQuery
	Proxy          FingerbankSettingsProxy
}

var FingerbankConf = FingerbankSettings{}
