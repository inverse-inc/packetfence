package file_paths

import "path/filepath"

// File paths for PacketFence. Ported from lib/pf/file_paths.pm.

const PF_DIR = "/usr/local/pf"

// Directories
var (
	INSTALL_DIR = PF_DIR
	BIN_DIR     = filepath.Join(PF_DIR, "bin")
	SBIN_DIR    = filepath.Join(PF_DIR, "sbin")
	CONF_DIR    = filepath.Join(PF_DIR, "conf")
	VAR_DIR     = filepath.Join(PF_DIR, "var")
	LIB_DIR     = filepath.Join(PF_DIR, "lib")
	HTML_DIR    = filepath.Join(PF_DIR, "html")
	LOG_DIR     = filepath.Join(PF_DIR, "logs")

	LOG_CONF_DIR     = filepath.Join(CONF_DIR, "log.conf.d")
	KAFKA_CONFIG_DIR = filepath.Join(CONF_DIR, "kafka")

	GENERATED_CONF_DIR           = filepath.Join(VAR_DIR, "conf")
	GENERATED_IPTABLES_CONF_DIR  = filepath.Join(GENERATED_CONF_DIR, "iptables")
	GENERATED_IP6TABLES_CONF_DIR = filepath.Join(GENERATED_CONF_DIR, "ip6tables")
	TT_COMPILE_CACHE_DIR         = filepath.Join(VAR_DIR, "tt_compile_cache")
	CONTROL_DIR                  = filepath.Join(VAR_DIR, "control")
	SWITCH_CONTROL_DIR           = filepath.Join(VAR_DIR, "switch_control")
	PFCONFIG_CACHE_DIR           = filepath.Join(VAR_DIR, "cache/pfconfig")
	RUN_DIR                      = filepath.Join(VAR_DIR, "run")
	DOMAINS_CHROOT_DIR           = "/chroots"
	DOMAINS_NTLM_CACHE_USERS_DIR = filepath.Join(VAR_DIR, "cache/ntlm_cache_users")
	SYSTEMD_UNIT_DIR             = "/usr/lib/systemd/system"
	ACME_CHALLENGE_DIR           = filepath.Join(CONF_DIR, "ssl/acme-challenge")
	CONF_UPLOADS                 = filepath.Join(CONF_DIR, "uploads")
	API_I18N_DIR                 = filepath.Join(CONF_DIR, "I18N/api")
	PFPERL_API_RESTART_TASK      = filepath.Join(VAR_DIR, "pfperl-api/restart-task")

	USERS_CERT_DIR = filepath.Join(HTML_DIR, "captive-portal/certs")

	CAPTIVEPORTAL_TEMPLATES_PATH                 = filepath.Join(PF_DIR, "html/captive-portal/templates")
	CAPTIVEPORTAL_PROFILE_TEMPLATES_PATH         = filepath.Join(PF_DIR, "html/captive-portal/profile-templates")
	CAPTIVEPORTAL_DEFAULT_PROFILE_TEMPLATES_PATH = filepath.Join(CAPTIVEPORTAL_PROFILE_TEMPLATES_PATH, "default")

	PF_ADMIN_I18N_DIR = filepath.Join(HTML_DIR, "pfappserver/lib/pfappserver/I18N")

	// Fingerbank directories
	FINGERBANK_CONFIG_DIRECTORY = "/usr/local/fingerbank/conf"
)

// Binaries
var (
	PFCMD_BINARY = filepath.Join(BIN_DIR, "pfcmd")
)

// Config files
var (
	OUI_FILE                  = filepath.Join(CONF_DIR, "oui.txt")
	SURICATA_CATEGORIES_FILE  = filepath.Join(CONF_DIR, "suricata_categories.txt")
	NEXPOSE_CATEGORIES_FILE   = filepath.Join(CONF_DIR, "nexpose-responses.txt")
	LOCAL_SECRET_FILE         = filepath.Join(CONF_DIR, "local_secret")
	UNIFIED_API_SYSTEM_PASS_FILE = filepath.Join(CONF_DIR, "unified_api_system_pass")
	SYSTEM_INIT_KEY_FILE      = filepath.Join(CONF_DIR, "system_init_key")
	PF_DOC_FILE               = filepath.Join(CONF_DIR, "documentation.conf")
	OAUTH_IP_FILE             = filepath.Join(CONF_DIR, "oauth2-ips.conf")
	UI_CONFIG_FILE            = filepath.Join(CONF_DIR, "ui.conf")
	PF_CONFIG_FILE            = filepath.Join(CONF_DIR, "pf.conf")
	PF_DEFAULT_FILE           = filepath.Join(CONF_DIR, "pf.conf.defaults")
	CHI_CONFIG_FILE           = filepath.Join(CONF_DIR, "chi.conf")
	CHI_DEFAULTS_CONFIG_FILE  = filepath.Join(CONF_DIR, "chi.conf.defaults")
	LOG_CONFIG_FILE           = filepath.Join(CONF_DIR, "log.conf")
	PROVISIONING_CONFIG_FILE  = filepath.Join(CONF_DIR, "provisioning.conf")
	SELF_SERVICE_CONFIG_FILE  = filepath.Join(CONF_DIR, "self_service.conf")
	SELF_SERVICE_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "self_service.conf.defaults")
	PKI_PROVIDER_CONFIG_FILE  = filepath.Join(CONF_DIR, "pki_provider.conf")
	SYSLOG_CONFIG_FILE        = filepath.Join(CONF_DIR, "syslog.conf")
	SYSLOG_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "syslog.conf.defaults")
	RSYSLOG_PACKETFENCE_CONFIG_FILE = "/etc/rsyslog.d/00-packetfence.conf"
	FINGERBANK_COLLECTOR_ENV_DEFAULTS_FILE = filepath.Join(CONF_DIR, "fingerbank-collector.env.defaults")
	NETWORK_BEHAVIOR_POLICY_CONFIG_FILE = filepath.Join(CONF_DIR, "network_behavior_policies.conf")

	NETWORK_CONFIG_FILE                   = filepath.Join(CONF_DIR, "networks.conf")
	SWITCHES_CONFIG_FILE                  = filepath.Join(CONF_DIR, "switches.conf")
	SWITCHES_DEFAULT_CONFIG_FILE          = filepath.Join(CONF_DIR, "switches.conf.defaults")
	TEMPLATE_SWITCHES_CONFIG_FILE         = filepath.Join(CONF_DIR, "template_switches.conf")
	TEMPLATE_SWITCHES_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "template_switches.conf.defaults")
	PROFILES_CONFIG_FILE                  = filepath.Join(CONF_DIR, "profiles.conf")
	PROFILES_DEFAULT_CONFIG_FILE          = filepath.Join(CONF_DIR, "profiles.conf.defaults")
	FLOATING_DEVICES_FILE                 = filepath.Join(CONF_DIR, "floating_network_device.conf")
	SECURITY_EVENTS_CONFIG_FILE           = filepath.Join(CONF_DIR, "security_events.conf")
	SECURITY_EVENTS_DEFAULT_CONFIG_FILE   = filepath.Join(CONF_DIR, "security_events.conf.defaults")
	DHCP_FINGERPRINTS_FILE                = filepath.Join(CONF_DIR, "dhcp_fingerprints.conf")
	ADMIN_ROLES_CONFIG_FILE               = filepath.Join(CONF_DIR, "adminroles.conf")

	AUTHENTICATION_CONFIG_FILE    = filepath.Join(CONF_DIR, "authentication.conf")
	EVENT_LOGGERS_CONFIG_FILE     = filepath.Join(CONF_DIR, "event_loggers.conf")
	FLOATING_DEVICES_CONFIG_FILE  = filepath.Join(CONF_DIR, "floating_network_device.conf")
	WRIX_CONFIG_FILE              = filepath.Join(CONF_DIR, "wrix.conf")
	ALLOWED_DEVICE_OUI_FILE       = filepath.Join(CONF_DIR, "allowed_device_oui.txt")
	ALLOWED_DEVICE_TYPES_FILE     = filepath.Join(CONF_DIR, "allowed_device_types.txt")
	VLAN_FILTERS_CONFIG_FILE      = filepath.Join(CONF_DIR, "vlan_filters.conf")
	VLAN_FILTERS_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "vlan_filters.conf.defaults")
	PROVISIONING_FILTERS_CONFIG_FILE          = filepath.Join(CONF_DIR, "provisioning_filters.conf")
	PROVISIONING_FILTERS_CONFIG_DEFAULT_FILE  = filepath.Join(CONF_DIR, "provisioning_filters.conf.defaults")
	PROVISIONING_FILTERS_META_CONFIG_FILE     = filepath.Join(CONF_DIR, "provisioning_filters_meta.conf")
	PROVISIONING_FILTERS_META_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "provisioning_filters_meta.conf.defaults")
	CLOUD_CONFIG_FILE             = filepath.Join(CONF_DIR, "cloud.conf")
	FIREWALL_SSO_CONFIG_FILE      = filepath.Join(CONF_DIR, "firewall_sso.conf")
	PFDETECT_CONFIG_FILE          = filepath.Join(CONF_DIR, "pfdetect.conf")
	PFQUEUE_CONFIG_FILE           = filepath.Join(CONF_DIR, "pfqueue.conf")
	REPORT_CONFIG_FILE            = filepath.Join(CONF_DIR, "report.conf")
	REPORT_DEFAULT_CONFIG_FILE    = filepath.Join(CONF_DIR, "report.conf.defaults")
	PFQUEUE_DEFAULT_CONFIG_FILE   = filepath.Join(CONF_DIR, "pfqueue.conf.defaults")
	REALM_CONFIG_FILE             = filepath.Join(CONF_DIR, "realm.conf")
	REALM_DEFAULT_CONFIG_FILE     = filepath.Join(CONF_DIR, "realm.conf.defaults")
	SURVEY_CONFIG_FILE            = filepath.Join(CONF_DIR, "survey.conf")
	CLUSTER_CONFIG_FILE           = filepath.Join(CONF_DIR, "cluster.conf")

	SERVER_KEY  = filepath.Join(CONF_DIR, "ssl/server.key")
	SERVER_CERT = filepath.Join(CONF_DIR, "ssl/server.crt")
	SERVER_PEM  = filepath.Join(CONF_DIR, "ssl/server.pem")

	RADIUS_SERVER_KEY  = filepath.Join(PF_DIR, "raddb/certs/server.key")
	RADIUS_SERVER_CERT = filepath.Join(PF_DIR, "raddb/certs/server.crt")
	RADIUS_CA_CERT     = filepath.Join(PF_DIR, "raddb/certs/ca.pem")

	SSL_CONFIGURATION_FILE = filepath.Join(GENERATED_CONF_DIR, "ssl-certificates.conf")
	MARIADB_PF_UDF_FILE    = filepath.Join(GENERATED_CONF_DIR, "mariadb_pf_udf")

	DOMAIN_CONFIG_FILE  = filepath.Join(CONF_DIR, "domain.conf")
	SCAN_CONFIG_FILE    = filepath.Join(CONF_DIR, "scan.conf")
	RADIUS_FILTERS_CONFIG_FILE         = filepath.Join(CONF_DIR, "radius_filters.conf")
	RADIUS_FILTERS_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "radius_filters.conf.defaults")
	BILLING_TIERS_CONFIG_FILE          = filepath.Join(CONF_DIR, "billing_tiers.conf")
	DHCP_FILTERS_CONFIG_FILE           = filepath.Join(CONF_DIR, "dhcp_filters.conf")
	ROLES_CONFIG_FILE                  = filepath.Join(CONF_DIR, "roles.conf")
	ROLES_DEFAULT_CONFIG_FILE          = filepath.Join(CONF_DIR, "roles.conf.defaults")
	DNS_FILTERS_CONFIG_FILE            = filepath.Join(CONF_DIR, "dns_filters.conf")
	DNS_FILTERS_DEFAULT_CONFIG_FILE    = filepath.Join(CONF_DIR, "dns_filters.conf.defaults")
	PORTAL_MODULES_CONFIG_FILE         = filepath.Join(CONF_DIR, "portal_modules.conf")
	PORTAL_MODULES_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "portal_modules.conf.defaults")
	CRON_CONFIG_FILE                   = filepath.Join(CONF_DIR, "pfcron.conf")
	CRON_DEFAULT_CONFIG_FILE           = filepath.Join(CONF_DIR, "pfcron.conf.defaults")
	SWITCH_FILTERS_CONFIG_FILE         = filepath.Join(CONF_DIR, "switch_filters.conf")
	STATS_CONFIG_FILE                  = filepath.Join(CONF_DIR, "stats.conf")
	STATS_CONFIG_DEFAULT_FILE          = filepath.Join(CONF_DIR, "stats.conf.defaults")
	IPTABLE_CUSTOM_CONFIG_FILE         = filepath.Join(CONF_DIR, "iptables-custom.conf.inc")
	IP6TABLE_CUSTOM_CONFIG_FILE        = filepath.Join(CONF_DIR, "ip6tables-custom.conf.inc")
	SSL_CONFIG_FILE                    = filepath.Join(CONF_DIR, "ssl.conf")
	SSL_DEFAULT_CONFIG_FILE            = filepath.Join(CONF_DIR, "ssl.conf.defaults")
	TLS_CONFIG_FILE                    = filepath.Join(CONF_DIR, "radiusd/tls.conf")
	TLS_DEFAULT_CONFIG_FILE            = filepath.Join(CONF_DIR, "radiusd/tls.conf.defaults")
	OCSP_CONFIG_FILE                   = filepath.Join(CONF_DIR, "radiusd/ocsp.conf")
	OCSP_DEFAULT_CONFIG_FILE           = filepath.Join(CONF_DIR, "radiusd/ocsp.conf.defaults")
	EAP_CONFIG_FILE                    = filepath.Join(CONF_DIR, "radiusd/eap_profiles.conf")
	EAP_DEFAULT_CONFIG_FILE            = filepath.Join(CONF_DIR, "radiusd/eap_profiles.conf.defaults")
	FAST_CONFIG_FILE                   = filepath.Join(CONF_DIR, "radiusd/fast.conf")
	FAST_DEFAULT_CONFIG_FILE           = filepath.Join(CONF_DIR, "radiusd/fast.conf.defaults")
	DNS_CONNECTORS_CONFIG_FILE         = filepath.Join(CONF_DIR, "dns_connectors.conf")
	DOMAINS_CONNECTORS_CONFIG_FILE     = filepath.Join(CONF_DIR, "domains_connectors.conf")

	MFA_CONFIG_FILE        = filepath.Join(CONF_DIR, "mfa.conf")
	KAFKA_CONFIG_FILE      = filepath.Join(CONF_DIR, "kafka.conf")
	CONNECTORS_CONFIG_FILE = filepath.Join(CONF_DIR, "connectors.conf")

	GIT_COMMIT_ID_FILE = filepath.Join(CONF_DIR, "git_commit_id")

	// Fingerbank config files
	FINGERBANK_CONFIG_FILE         = filepath.Join(FINGERBANK_CONFIG_DIRECTORY, "fingerbank.conf")
	FINGERBANK_DEFAULT_CONFIG_FILE = filepath.Join(FINGERBANK_CONFIG_DIRECTORY, "fingerbank.conf.defaults")
	FINGERBANK_DOC_FILE            = filepath.Join(FINGERBANK_CONFIG_DIRECTORY, "fingerbank.conf.doc")
)

// Runtime / state files & sockets
var (
	PFFILTER_SOCKET_PATH   = filepath.Join(VAR_DIR, "run/pffilter.sock")
	PFQUEUE_BACKEND_SOCKET = filepath.Join(RUN_DIR, "pfqueue-backend.sock")
	CACHE_CONTROL_FILE     = filepath.Join(VAR_DIR, "cache_control")
	CONFIG_VERSION_FILE    = filepath.Join(VAR_DIR, "conf/config_version")
	MAINTENANCE_FILE       = filepath.Join(VAR_DIR, "maintenance-mode")
)

// External URLs
const (
	OUI_URL               = "http://standards.ieee.org/regauth/oui/oui.txt"
	DHCP_FINGERPRINTS_URL = "http://www.packetfence.org/dhcp_fingerprints.conf"
)

// LogFiles returns the list of PacketFence log files (absolute paths).
func LogFiles() []string {
	names := []string{
		"fingerbank.log", "httpd.apache", "api-frontend.log",
		"pfacct.log", "pfstats.log", "packetfence.log", "pfdhcp.log",
		"pfdns.log", "pfconfig.log", "pfdetect.log", "pffilter.log",
		"pfdhcplistener.log", "pfcron.log", "pfsso.log",
		"radius-acct.log", "radius-eduroam.log", "radius-load_balancer.log",
		"radius.log", "redis-cache.log", "redis_ntlm_cache.log",
		"redis_queue.log", "redis_server.log", "mariadb.log",
		"mysql-probe.log", "galera-autofix.log", "haproxy_portal.log",
		"haproxy.log", "haproxy_db.log", "haproxy_admin.log", "proxysql.log",
		"firewall.log", "pfconnector-client.log", "pfconnector-server.log", "keepalived.log",
		"innobackup.log",
	}
	out := make([]string, len(names))
	for i, n := range names {
		out[i] = filepath.Join(LOG_DIR, n)
	}
	return out
}

// StoredConfigFiles returns the list of config files persisted by PacketFence.
func StoredConfigFiles() []string {
	return []string{
		PF_CONFIG_FILE, NETWORK_CONFIG_FILE,
		SWITCHES_CONFIG_FILE, SECURITY_EVENTS_CONFIG_FILE,
		AUTHENTICATION_CONFIG_FILE, FLOATING_DEVICES_CONFIG_FILE,
		DHCP_FINGERPRINTS_FILE, PROFILES_CONFIG_FILE,
		OUI_FILE, FLOATING_DEVICES_FILE,
		CHI_CONFIG_FILE, ALLOWED_DEVICE_OUI_FILE, ALLOWED_DEVICE_TYPES_FILE,
		UI_CONFIG_FILE, PROVISIONING_CONFIG_FILE, OAUTH_IP_FILE, LOG_CONFIG_FILE,
		SELF_SERVICE_CONFIG_FILE,
		ADMIN_ROLES_CONFIG_FILE, WRIX_CONFIG_FILE,
		VLAN_FILTERS_CONFIG_FILE, VLAN_FILTERS_CONFIG_DEFAULT_FILE, CLOUD_CONFIG_FILE, FIREWALL_SSO_CONFIG_FILE, SCAN_CONFIG_FILE,
		PFDETECT_CONFIG_FILE, PFQUEUE_CONFIG_FILE,
		PKI_PROVIDER_CONFIG_FILE,
		RADIUS_FILTERS_CONFIG_FILE, RADIUS_FILTERS_CONFIG_DEFAULT_FILE,
		DHCP_FILTERS_CONFIG_FILE,
		ROLES_CONFIG_FILE,
		DNS_FILTERS_CONFIG_FILE,
		SWITCH_FILTERS_CONFIG_FILE,
		STATS_CONFIG_FILE,
		SYSLOG_CONFIG_FILE,
		REALM_CONFIG_FILE,
		FINGERBANK_COLLECTOR_ENV_DEFAULTS_FILE,
		PORTAL_MODULES_CONFIG_FILE,
		TEMPLATE_SWITCHES_CONFIG_FILE,
		SSL_CONFIG_FILE,
		CRON_CONFIG_FILE,
		DOMAIN_CONFIG_FILE,
		MFA_CONFIG_FILE,
		KAFKA_CONFIG_FILE,
		CONNECTORS_CONFIG_FILE,
		CLUSTER_CONFIG_FILE,
	}
}
