package file_paths

import "path/filepath"

const PF_DIR = "/usr/local/pf"

// Directories
var BIN_DIR = filepath.Join(PF_DIR, "bin")
var SBIN_DIR = filepath.Join(PF_DIR, "sbin")
var CONF_DIR = filepath.Join(PF_DIR, "conf")
var VAR_DIR = filepath.Join(PF_DIR, "var")
var LIB_DIR = filepath.Join(PF_DIR, "lib")
var HTML_DIR = filepath.Join(PF_DIR, "html")
var LOG_DIR = filepath.Join(PF_DIR, "logs")
var LOG_CONF_DIR = filepath.Join(CONF_DIR, "log.conf.d")
var KAFKA_CONFIG_DIR = filepath.Join(CONF_DIR, "kafka")

var GENERATED_CONF_DIR = filepath.Join(VAR_DIR, "conf")
var GENERATED_IPTABLES_CONF_DIR = filepath.Join(GENERATED_CONF_DIR, "iptables")
var GENERATED_IP6TABLES_CONF_DIR = filepath.Join(GENERATED_CONF_DIR, "ip6tables")
var TT_COMPILE_CACHE_DIR = filepath.Join(VAR_DIR, "tt_compile_cache")
var CONTROL_DIR = filepath.Join(VAR_DIR, "control")
var SWITCH_CONTROL_DIR = filepath.Join(VAR_DIR, "switch_control")
var PFCONFIG_CACHE_DIR = filepath.Join(VAR_DIR, "cache", "pfconfig")
var RUN_DIR = filepath.Join(VAR_DIR, "run")
var DOMAINS_CHROOT_DIR = "/chroots"
var DOMAINS_NTLM_CACHE_USERS_DIR = filepath.Join(VAR_DIR, "cache", "ntlm_cache_users")

const SYSTEMD_UNIT_DIR = "/usr/lib/systemd/system"

var ACME_CHALLENGE_DIR = filepath.Join(CONF_DIR, "ssl", "acme-challenge")
var CONF_UPLOADS = filepath.Join(CONF_DIR, "uploads")
var API_I18N_DIR = filepath.Join(CONF_DIR, "I18N", "api")
var PFPERL_API_RESTART_TASK = filepath.Join(VAR_DIR, "pfperl-api", "restart-task")

var USERS_CERT_DIR = filepath.Join(HTML_DIR, "captive-portal", "certs")

var CAPTIVEPORTAL_TEMPLATES_PATH = filepath.Join(PF_DIR, "html", "captive-portal", "templates")
var CAPTIVEPORTAL_PROFILE_TEMPLATES_PATH = filepath.Join(PF_DIR, "html", "captive-portal", "profile-templates")
var CAPTIVEPORTAL_DEFAULT_PROFILE_TEMPLATES_PATH = filepath.Join(CAPTIVEPORTAL_PROFILE_TEMPLATES_PATH, "default")

var PF_ADMIN_I18N_DIR = filepath.Join(HTML_DIR, "pfappserver", "lib", "pfappserver", "I18N")

// Fingerbank
const FINGERBANK_CONFIG_DIRECTORY = "/usr/local/fingerbank/conf"

var FINGERBANK_CONFIG_FILE = filepath.Join(FINGERBANK_CONFIG_DIRECTORY, "fingerbank.conf")
var FINGERBANK_DEFAULT_CONFIG_FILE = filepath.Join(FINGERBANK_CONFIG_DIRECTORY, "fingerbank.conf.defaults")
var FINGERBANK_DOC_FILE = filepath.Join(FINGERBANK_CONFIG_DIRECTORY, "fingerbank.conf.doc")

// Binaries
var PFCMD_BINARY = filepath.Join(BIN_DIR, "pfcmd")

// Config files
var PF_DEFAULT_FILE = filepath.Join(CONF_DIR, "pf.conf.defaults")
var PF_CONFIG_FILE = filepath.Join(CONF_DIR, "pf.conf")
var NETWORK_CONFIG_FILE = filepath.Join(CONF_DIR, "networks.conf")
var OAUTH_IP_FILE = filepath.Join(CONF_DIR, "oauth2-ips.conf")
var PF_DOC_FILE = filepath.Join(CONF_DIR, "documentation.conf")
var UI_CONFIG_FILE = filepath.Join(CONF_DIR, "ui.conf")
var CHI_CONFIG_FILE = filepath.Join(CONF_DIR, "chi.conf")
var CHI_DEFAULTS_CONFIG_FILE = filepath.Join(CONF_DIR, "chi.conf.defaults")
var LOG_CONFIG_FILE = filepath.Join(CONF_DIR, "log.conf")
var PROVISIONING_CONFIG_FILE = filepath.Join(CONF_DIR, "provisioning.conf")
var SELF_SERVICE_CONFIG_FILE = filepath.Join(CONF_DIR, "self_service.conf")
var SELF_SERVICE_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "self_service.conf.defaults")
var PKI_PROVIDER_CONFIG_FILE = filepath.Join(CONF_DIR, "pki_provider.conf")
var SYSLOG_CONFIG_FILE = filepath.Join(CONF_DIR, "syslog.conf")
var SYSLOG_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "syslog.conf.defaults")
var FINGERBANK_COLLECTOR_ENV_DEFAULTS_FILE = filepath.Join(CONF_DIR, "fingerbank-collector.env.defaults")
var NETWORK_BEHAVIOR_POLICY_CONFIG_FILE = filepath.Join(CONF_DIR, "network_behavior_policies.conf")
var SWITCHES_CONFIG_FILE = filepath.Join(CONF_DIR, "switches.conf")
var SWITCHES_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "switches.conf.defaults")
var TEMPLATE_SWITCHES_CONFIG_FILE = filepath.Join(CONF_DIR, "template_switches.conf")
var TEMPLATE_SWITCHES_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "template_switches.conf.defaults")
var PROFILES_CONFIG_FILE = filepath.Join(CONF_DIR, "profiles.conf")
var PROFILES_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "profiles.conf.defaults")
var FLOATING_DEVICES_FILE = filepath.Join(CONF_DIR, "floating_network_device.conf")
var FLOATING_DEVICES_CONFIG_FILE = filepath.Join(CONF_DIR, "floating_network_device.conf")
var SECURITY_EVENTS_CONFIG_FILE = filepath.Join(CONF_DIR, "security_events.conf")
var SECURITY_EVENTS_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "security_events.conf.defaults")
var DHCP_FINGERPRINTS_FILE = filepath.Join(CONF_DIR, "dhcp_fingerprints.conf")
var ADMIN_ROLES_CONFIG_FILE = filepath.Join(CONF_DIR, "adminroles.conf")
var AUTHENTICATION_CONFIG_FILE = filepath.Join(CONF_DIR, "authentication.conf")
var EVENT_LOGGERS_CONFIG_FILE = filepath.Join(CONF_DIR, "event_loggers.conf")
var WRIX_CONFIG_FILE = filepath.Join(CONF_DIR, "wrix.conf")
var ALLOWED_DEVICE_OUI_FILE = filepath.Join(CONF_DIR, "allowed_device_oui.txt")
var ALLOWED_DEVICE_TYPES_FILE = filepath.Join(CONF_DIR, "allowed_device_types.txt")
var VLAN_FILTERS_CONFIG_FILE = filepath.Join(CONF_DIR, "vlan_filters.conf")
var VLAN_FILTERS_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "vlan_filters.conf.defaults")
var PROVISIONING_FILTERS_CONFIG_FILE = filepath.Join(CONF_DIR, "provisioning_filters.conf")
var PROVISIONING_FILTERS_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "provisioning_filters.conf.defaults")
var PROVISIONING_FILTERS_META_CONFIG_FILE = filepath.Join(CONF_DIR, "provisioning_filters_meta.conf")
var PROVISIONING_FILTERS_META_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "provisioning_filters_meta.conf.defaults")
var CLOUD_CONFIG_FILE = filepath.Join(CONF_DIR, "cloud.conf")
var FIREWALL_SSO_CONFIG_FILE = filepath.Join(CONF_DIR, "firewall_sso.conf")
var PFDETECT_CONFIG_FILE = filepath.Join(CONF_DIR, "pfdetect.conf")
var PFQUEUE_CONFIG_FILE = filepath.Join(CONF_DIR, "pfqueue.conf")
var PFQUEUE_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "pfqueue.conf.defaults")
var REPORT_CONFIG_FILE = filepath.Join(CONF_DIR, "report.conf")
var REPORT_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "report.conf.defaults")
var REALM_CONFIG_FILE = filepath.Join(CONF_DIR, "realm.conf")
var REALM_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "realm.conf.defaults")
var SURVEY_CONFIG_FILE = filepath.Join(CONF_DIR, "survey.conf")
var CLUSTER_CONFIG_FILE = filepath.Join(CONF_DIR, "cluster.conf")
var DOMAIN_CONFIG_FILE = filepath.Join(CONF_DIR, "domain.conf")
var SCAN_CONFIG_FILE = filepath.Join(CONF_DIR, "scan.conf")
var RADIUS_FILTERS_CONFIG_FILE = filepath.Join(CONF_DIR, "radius_filters.conf")
var RADIUS_FILTERS_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "radius_filters.conf.defaults")
var BILLING_TIERS_CONFIG_FILE = filepath.Join(CONF_DIR, "billing_tiers.conf")
var DHCP_FILTERS_CONFIG_FILE = filepath.Join(CONF_DIR, "dhcp_filters.conf")
var ROLES_CONFIG_FILE = filepath.Join(CONF_DIR, "roles.conf")
var ROLES_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "roles.conf.defaults")
var DNS_FILTERS_CONFIG_FILE = filepath.Join(CONF_DIR, "dns_filters.conf")
var DNS_FILTERS_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "dns_filters.conf.defaults")
var PORTAL_MODULES_CONFIG_FILE = filepath.Join(CONF_DIR, "portal_modules.conf")
var PORTAL_MODULES_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "portal_modules.conf.defaults")
var CRON_CONFIG_FILE = filepath.Join(CONF_DIR, "pfcron.conf")
var CRON_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "pfcron.conf.defaults")
var SWITCH_FILTERS_CONFIG_FILE = filepath.Join(CONF_DIR, "switch_filters.conf")
var STATS_CONFIG_FILE = filepath.Join(CONF_DIR, "stats.conf")
var STATS_CONFIG_DEFAULT_FILE = filepath.Join(CONF_DIR, "stats.conf.defaults")
var IPTABLE_CUSTOM_CONFIG_FILE = filepath.Join(CONF_DIR, "iptables-custom.conf.inc")
var IP6TABLE_CUSTOM_CONFIG_FILE = filepath.Join(CONF_DIR, "ip6tables-custom.conf.inc")
var SSL_CONFIG_FILE = filepath.Join(CONF_DIR, "ssl.conf")
var SSL_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "ssl.conf.defaults")
var TLS_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "tls.conf")
var TLS_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "tls.conf.defaults")
var OCSP_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "ocsp.conf")
var OCSP_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "ocsp.conf.defaults")
var EAP_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "eap_profiles.conf")
var EAP_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "eap_profiles.conf.defaults")
var FAST_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "fast.conf")
var FAST_DEFAULT_CONFIG_FILE = filepath.Join(CONF_DIR, "radiusd", "fast.conf.defaults")
var DNS_CONNECTORS_CONFIG_FILE = filepath.Join(CONF_DIR, "dns_connectors.conf")
var DOMAINS_CONNECTORS_CONFIG_FILE = filepath.Join(CONF_DIR, "domains_connectors.conf")
var MFA_CONFIG_FILE = filepath.Join(CONF_DIR, "mfa.conf")
var KAFKA_CONFIG_FILE = filepath.Join(CONF_DIR, "kafka.conf")
var CONNECTORS_CONFIG_FILE = filepath.Join(CONF_DIR, "connectors.conf")

// SSL / TLS certificates
var SERVER_KEY = filepath.Join(CONF_DIR, "ssl", "server.key")
var SERVER_CERT = filepath.Join(CONF_DIR, "ssl", "server.crt")
var SERVER_PEM = filepath.Join(CONF_DIR, "ssl", "server.pem")
var RADIUS_SERVER_KEY = filepath.Join(PF_DIR, "raddb", "certs", "server.key")
var RADIUS_SERVER_CERT = filepath.Join(PF_DIR, "raddb", "certs", "server.crt")
var RADIUS_CA_CERT = filepath.Join(PF_DIR, "raddb", "certs", "ca.pem")
var SSL_CONFIGURATION_FILE = filepath.Join(GENERATED_CONF_DIR, "ssl-certificates.conf")

// MariaDB
var MARIADB_PF_UDF_FILE = filepath.Join(GENERATED_CONF_DIR, "mariadb_pf_udf")

// OUI / DHCP fingerprints data files
var OUI_FILE = filepath.Join(CONF_DIR, "oui.txt")
var SURICATA_CATEGORIES_FILE = filepath.Join(CONF_DIR, "suricata_categories.txt")
var NEXPOSE_CATEGORIES_FILE = filepath.Join(CONF_DIR, "nexpose-responses.txt")

// Secrets
var LOCAL_SECRET_FILE = filepath.Join(CONF_DIR, "local_secret")
var UNIFIED_API_SYSTEM_PASS_FILE = filepath.Join(CONF_DIR, "unified_api_system_pass")
var SYSTEM_INIT_KEY_FILE = filepath.Join(CONF_DIR, "system_init_key")

// Rsyslog
const RSYSLOG_PACKETFENCE_CONFIG_FILE = "/etc/rsyslog.d/packetfence.conf"

// Sockets
var PFFILTER_SOCKET_PATH = filepath.Join(VAR_DIR, "run", "pffilter.sock")
var PFQUEUE_BACKEND_SOCKET = filepath.Join(RUN_DIR, "pfqueue-backend.sock")

// Other var files
var CACHE_CONTROL_FILE = filepath.Join(VAR_DIR, "cache_control")
var CONFIG_VERSION_FILE = filepath.Join(VAR_DIR, "conf", "config_version")
var MAINTENANCE_FILE = filepath.Join(VAR_DIR, "maintenance-mode")
var GIT_COMMIT_ID_FILE = filepath.Join(CONF_DIR, "git_commit_id")

// URLs
const OUI_URL = "http://standards.ieee.org/regauth/oui/oui.txt"
const DHCP_FINGERPRINTS_URL = "http://www.packetfence.org/dhcp_fingerprints.conf"

// Log files
var LOG_FILES = []string{
	filepath.Join(LOG_DIR, "fingerbank.log"),
	filepath.Join(LOG_DIR, "httpd.apache"),
	filepath.Join(LOG_DIR, "api-frontend.log"),
	filepath.Join(LOG_DIR, "pfacct.log"),
	filepath.Join(LOG_DIR, "pfstats.log"),
	filepath.Join(LOG_DIR, "packetfence.log"),
	filepath.Join(LOG_DIR, "pfdhcp.log"),
	filepath.Join(LOG_DIR, "pfdns.log"),
	filepath.Join(LOG_DIR, "pfconfig.log"),
	filepath.Join(LOG_DIR, "pfdetect.log"),
	filepath.Join(LOG_DIR, "pffilter.log"),
	filepath.Join(LOG_DIR, "pfdhcplistener.log"),
	filepath.Join(LOG_DIR, "pfcron.log"),
	filepath.Join(LOG_DIR, "pfsso.log"),
	filepath.Join(LOG_DIR, "radius-acct.log"),
	filepath.Join(LOG_DIR, "radius-eduroam.log"),
	filepath.Join(LOG_DIR, "radius-load_balancer.log"),
	filepath.Join(LOG_DIR, "radius.log"),
	filepath.Join(LOG_DIR, "redis-cache.log"),
	filepath.Join(LOG_DIR, "redis_ntlm_cache.log"),
	filepath.Join(LOG_DIR, "redis_queue.log"),
	filepath.Join(LOG_DIR, "redis_server.log"),
	filepath.Join(LOG_DIR, "mariadb.log"),
	filepath.Join(LOG_DIR, "mysql-probe.log"),
	filepath.Join(LOG_DIR, "galera-autofix.log"),
	filepath.Join(LOG_DIR, "haproxy_portal.log"),
	filepath.Join(LOG_DIR, "haproxy.log"),
	filepath.Join(LOG_DIR, "haproxy_db.log"),
	filepath.Join(LOG_DIR, "haproxy_admin.log"),
	filepath.Join(LOG_DIR, "proxysql.log"),
	filepath.Join(LOG_DIR, "firewall.log"),
	filepath.Join(LOG_DIR, "pfconnector-client.log"),
	filepath.Join(LOG_DIR, "pfconnector-server.log"),
	filepath.Join(LOG_DIR, "keepalived.log"),
	filepath.Join(LOG_DIR, "innobackup.log"),
}

// Stored config files
var STORED_CONFIG_FILES = []string{
	PF_CONFIG_FILE,
	NETWORK_CONFIG_FILE,
	SWITCHES_CONFIG_FILE,
	SECURITY_EVENTS_CONFIG_FILE,
	AUTHENTICATION_CONFIG_FILE,
	FLOATING_DEVICES_CONFIG_FILE,
	DHCP_FINGERPRINTS_FILE,
	PROFILES_CONFIG_FILE,
	OUI_FILE,
	FLOATING_DEVICES_FILE,
	CHI_CONFIG_FILE,
	ALLOWED_DEVICE_OUI_FILE,
	ALLOWED_DEVICE_TYPES_FILE,
	UI_CONFIG_FILE,
	PROVISIONING_CONFIG_FILE,
	OAUTH_IP_FILE,
	LOG_CONFIG_FILE,
	SELF_SERVICE_CONFIG_FILE,
	ADMIN_ROLES_CONFIG_FILE,
	WRIX_CONFIG_FILE,
	VLAN_FILTERS_CONFIG_FILE,
	VLAN_FILTERS_CONFIG_DEFAULT_FILE,
	CLOUD_CONFIG_FILE,
	FIREWALL_SSO_CONFIG_FILE,
	SCAN_CONFIG_FILE,
	PFDETECT_CONFIG_FILE,
	PFQUEUE_CONFIG_FILE,
	PKI_PROVIDER_CONFIG_FILE,
	RADIUS_FILTERS_CONFIG_FILE,
	RADIUS_FILTERS_CONFIG_DEFAULT_FILE,
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
