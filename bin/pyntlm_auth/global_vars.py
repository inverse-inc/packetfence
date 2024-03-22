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


s_machine_cred = None
s_secure_channel_connection = None
s_connection_id = 1
s_reconnect_id = 0
s_connection_last_active_time = datetime.datetime.now()

s_lock = threading.Lock()

c_netbios_name = None
c_realm = None
c_server_string = None
c_workgroup = None
c_workstation = None
c_password = None
c_domain = None
c_username = None
c_server_name = None

c_nt_key_cache_enabled = None
c_nt_key_cache_expire = None
c_nt_key_cache = None
c_max_allowed_password_attempt = 3
c_reset_account_lockout_counter_after = 3600
c_old_password_allowed_period = 0

c_max_allowed_bad_password_per_device = 2
c_max_allowed_bad_password_total = 5
c_perform_transitive_login_after_cache_hit_for = 1

c_listen_port = None
c_domain_identifier = None
c_db_host = None
c_db_port = None
c_db_user = None
c_db_pass = None
c_db = None