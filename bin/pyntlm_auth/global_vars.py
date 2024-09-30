import datetime
import threading

_global_dict = {}


def _init():
    global _global_dict
    _global_dict = {}


def set_value(key, value):
    _global_dict[key] = value


def get_value(key, value=None):
    try:
        return _global_dict[key]
    except KeyError:
        return value


# global shared variables
s_machine_cred = None
s_secure_channel_connection = None
s_connection_id = 1
s_reconnect_id = 0
s_connection_last_active_time = datetime.datetime.now()

s_lock = threading.Lock()

# config for domain.conf - AD
c_netbios_name = None
c_realm = None
c_server_string = None
c_workgroup = None
c_workstation = None
c_password = None
c_additional_machine_accounts = None
c_domain = None
c_username = None
c_server_name = None
c_listen_port = None
c_domain_identifier = None
c_dns_servers = None

# config for domain.conf - db
c_db_host = None
c_db_port = None
c_db_user = None
c_db_pass = None
c_db = None
c_db_unix_socket = None

# config for domain.conf - nt key cache
c_nt_key_cache_enabled = None
c_nt_key_cache_expire = None

c_ad_account_lockout_threshold = 0                  # 0..999. Default=0, never locks
c_ad_account_lockout_duration = None                # Default not set
c_ad_reset_account_lockout_counter_after = None     # Default not set
c_ad_old_password_allowed_period = None             # Windows 2003+, Default not set, if not set, 60

c_max_allowed_password_attempts_per_device = None

