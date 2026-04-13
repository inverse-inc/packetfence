import datetime
import log
import utils

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

s_lock = None

s_worker = None  # gunicorn worker object.
s_bind_account = None  # machine account bind to specific worker
s_computer_account_base = None
s_password_ro = None  # machine account password loaded from config file

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
c_ad_server = None
c_ad_server_port = None
c_encryption = None
c_listen_port = None
c_domain_identifier = None
c_cache_domain = None
c_dns_servers = None

# config for domain.conf - db
c_db_host = None
c_db_port = None
c_db_user = None
c_db_pass = None
c_db = None
c_db_unix_socket = None

# config for domain.conf - redis cache
c_cache_host = None
c_cache_port = None

# config for domain.conf - nt key cache
c_nt_key_cache_enabled = None
c_nt_key_cache_expire = None

c_ad_account_lockout_threshold = 0  # 0..999. Default=0, never locks
c_ad_account_lockout_duration = None  # Default not set
c_ad_reset_account_lockout_counter_after = None  # Default not set
c_ad_old_password_allowed_period = None  # Windows 2003+, Default not set, if not set, 60

c_max_allowed_password_attempts_per_device = None
c_client_key_file = None
c_ca_file = None


def _debug():
    log.debug("loaded global variables")
    log.debug(f"---- Domain profile settings ----")
    log.debug(f"global_vars.c_server_name                   {c_server_name}")
    log.debug(f"global_vars.c_ad_server                     {c_ad_server}")
    log.debug(f"global_vars.c_realm                         {c_realm}")
    log.debug(f"global_vars.c_workgroup                     {c_workgroup}")
    log.debug(f"global_vars.c_username                      {c_username}")
    log.debug(f"global_vars.c_password                      {utils.mask_password(c_password)}")
    log.debug(f"global_vars.c_additional_machine_accounts   {c_additional_machine_accounts}")
    log.debug(f"global_vars.c_netbios_name                  {c_netbios_name}")
    log.debug(f"global_vars.c_workstation                   {c_workstation}")
    log.debug(f"global_vars.c_server_string                 {c_server_string}")
    log.debug(f"global_vars.c_domain                        {c_domain}")
    log.debug(f"global_vars.c_dns_servers                   {c_dns_servers}")

    log.debug(f"---- NT Key cache ----")
    log.debug(f"global_vars.c_nt_key_cache_enabled  {c_nt_key_cache_enabled}")
    log.debug(f"global_vars.c_nt_key_cache_expire   {c_nt_key_cache_expire}")
    log.debug(f"global_vars.c_ad_account_lockout_threshold              {c_ad_account_lockout_threshold}")
    log.debug(f"global_vars.c_ad_account_lockout_duration               {c_ad_account_lockout_duration}")
    log.debug(f"global_vars.c_ad_reset_account_lockout_counter_after    {c_ad_reset_account_lockout_counter_after}")
    log.debug(f"global_vars.c_ad_old_password_allowed_period            {c_ad_old_password_allowed_period}")
    log.debug(f"global_vars.c_max_allowed_password_attempts_per_device  {c_max_allowed_password_attempts_per_device}")

    log.debug(f"---- Database ----")
    log.debug(f"global_vars.c_db_host           {c_db_host}")
    log.debug(f"global_vars.c_db_port           {c_db_port}")
    log.debug(f"global_vars.c_db_user           {c_db_user}")
    log.debug(f"global_vars.c_db_pass           {utils.mask_password(c_db_pass)}")
    log.debug(f"global_vars.c_db                {c_db}")
    log.debug(f"global_vars.c_db_unix_socket    {c_db_unix_socket}")

    log.debug("---- Multi workers ----")
    log.debug(f"global_vars.c_cache_host    {c_cache_host}")
    log.debug(f"global_vars.c_cache_port    {c_cache_port}")
    log.debug(f"global_vars.s_computer_account_base     {s_computer_account_base}")