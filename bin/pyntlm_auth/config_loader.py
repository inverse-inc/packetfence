import configparser
import os
import socket
import sys
import time
from configparser import ConfigParser

import redis

import config_generator
import global_vars
import redis_client
import utils


def expand_machine_account_list():
    return (
        "pf1",
        "pf2",
        "pf3",
    )


def bind_machine_account(worker_pid):
    machine_accounts = expand_machine_account_list()
    for m in machine_accounts:
        try:
            key = f"{redis_client.namespace}:machine-account-bind:{m}"
            res = redis_client.r.set(name=key, value=worker_pid, nx=True, ex=10)
            if res is True:
                return m
        except redis.ConnectionError:
            print("redis connection error when trying to bind machine account.")
        except Exception as e:
            print(f"unexpected error when trying to bind machine account: {str(e)}")

    return None


def get_boolean_value(v):
    false_dict = ('', '0', 'no', 'n', 'false', 'off', 'disabled')

    if v is None:
        return False

    if isinstance(v, bool):
        return v

    if isinstance(v, str):
        v = v.lower().strip()
        if v in false_dict:
            return False

    return True


def get_int_value(v):
    try:
        ret = int(v)
        return ret, None
    except ValueError as e:
        return None, 'Value error, can not convert specified value to int'
    except Exception as e:
        return None, 'General error, can not convert specified value to int'


def config_load():
    global_vars.c_listen_port = os.getenv("LISTEN")
    global_vars.c_domain_identifier = socket.gethostname() + " " + os.getenv("IDENTIFIER")

    if global_vars.c_domain_identifier == "" or global_vars.c_listen_port == "":
        print("Unable to start ntlm-auth-api: 'IDENTIFIER' or 'LISTEN' is missing.")
        exit(1)

    print(f"ntlm-auth-api@{global_vars.c_domain_identifier} on port {global_vars.c_listen_port}...")

    identifier = global_vars.c_domain_identifier

    conf_dm = "/usr/local/pf/conf/domain.conf"
    cp_dm = ConfigParser(interpolation=None)
    print(f"Load domain config from {conf_dm}")
    try:
        with open(conf_dm, 'r') as file:
            cp_dm.read_file(file)
        if identifier not in cp_dm:
            print(f"  Section {identifier} does not exist in domain.conf. Terminated.")
            sys.exit(1)
    except FileNotFoundError:
        print(f"  {conf_dm} not found or unreadable. Terminated.")
        sys.exit(1)
    except configparser.Error as e:
        print(f"  Error loading config from domain.conf: {e}. Terminated.")
        sys.exit(1)

    conf_db = f"/usr/local/pf/var/conf/ntlm-auth-api.d/db.ini"
    cp_db = ConfigParser(interpolation=None)
    print(f"Load database config from {conf_db}")
    try:
        with open(conf_db, 'r') as file:
            cp_db.read_file(file)
        if 'DB' not in cp_db:
            print(f"  Section [DB] not found, ntlm-auth-api starts without NT Key caching capability.")
    except FileNotFoundError:
        print(f"  {conf_db} not found, ntlm-auth-api@{identifier} starts without NT Key caching capability.")
    except configparser.Error as e:
        print(f"  Error loading {conf_db}: {e}, ntlm-auth-api@{identifier} starts without NT Key caching capability.")

    server_name_raw = cp_dm.get(identifier, 'server_name')
    server_name_or_hostname = server_name_raw
    if "%h" in server_name_or_hostname.strip():
        ph = socket.gethostname().split(".")[0]
        server_name_or_hostname = server_name_or_hostname.replace("%h", ph)

    ad_fqdn = cp_dm.get(identifier, 'ad_fqdn')
    ad_server = cp_dm.get(identifier, 'ad_server')
    realm = cp_dm.get(identifier, 'dns_name')
    workgroup = cp_dm.get(identifier, 'workgroup')
    dns_servers = cp_dm.get(identifier, 'dns_servers')
    username = server_name_or_hostname.upper() + "$"
    password = cp_dm.get(identifier, 'machine_account_password')

    netbios_name = server_name_or_hostname.upper()
    workstation = server_name_or_hostname.upper()
    server_string = server_name_or_hostname
    domain = workgroup.lower()

    nt_key_cache_enabled = cp_dm.get(identifier, 'nt_key_cache_enabled', fallback=False)
    nt_key_cache_expire = cp_dm.get(identifier, 'nt_key_cache_expire', fallback=12000)
    ad_account_lockout_threshold = cp_dm.get(identifier, 'ad_account_lockout_threshold', fallback=0)
    max_allowed_attempts_per_device = cp_dm.get(identifier, 'max_allowed_password_attempts_per_device', fallback=0)
    ad_account_lockout_duration = cp_dm.get(identifier, 'ad_account_lockout_duration', fallback=0)
    ad_reset_account_lockout_count_after = cp_dm.get(identifier, 'ad_reset_account_lockout_counter_after', fallback=0)
    ad_old_password_allowed_period = cp_dm.get(identifier, 'ad_old_password_allowed_period', fallback=60)

    c_db_host = cp_db.get('DB', "DB_HOST", fallback=None)
    c_db_port = cp_db.get('DB', "DB_PORT", fallback=None)
    c_db_user = cp_db.get('DB', "DB_USER", fallback=None)
    c_db_pass = cp_db.get('DB', "DB_PASS", fallback=None)
    c_db = cp_db.get('DB', "DB", fallback=None)
    c_db_unix_socket = cp_db.get('DB', 'DB_UNIX_SOCKET', fallback=None)
    print(f"  {c_db_user}:{utils.mask_password(c_db_pass)}@{c_db_host}:{c_db_port}/{c_db}")

    # validate domain.conf
    print(f"starting ntlm-auth-api@{identifier}")
    if ad_fqdn == "":
        print("  'ad_fqdn' is not set. NTLM Auth API wasn't able to start")
        sys.exit(1)

    if dns_servers != "":
        config_generator.generate_resolv_conf(realm, dns_servers)
        time.sleep(1)
        ip, err_msg = utils.dns_lookup(ad_fqdn, "")
        if ip != "" and err_msg == "":
            print(f"  AD FQDN: {ad_fqdn} resolved with IP: {ip}.")
        else:
            if utils.is_ipv4(ad_server):  # if it's not resolvable, we use static IP provided in domain.conf
                print(f"  AD FQDN resolving failed. Starting with static hosts entry: {ad_server} {ad_fqdn}.")
                config_generator.generate_hosts_entry(ad_server, ad_fqdn)
            else:
                print("  Failed to retrieve IP address of AD server. Terminated.")
                sys.exit(1)
    else:
        if utils.is_ipv4(ad_server):
            config_generator.generate_hosts_entry(ad_server, ad_fqdn)
            print(f"  DNS servers not available, Starting using static hosts entry: {ad_server} {ad_fqdn}.")
        else:
            print("  Unable to start NTLM Auth API. 'ad_server' must be a valid IPv4 if DNS servers not specified.")
            sys.exit(1)

    print("NTLM Auth API started with the following parameters:")
    print(f"  ad_fqdn                   : {ad_fqdn}")
    print(f"  ad_server                 : {ad_server}")
    print(f"  server_name               : {server_name_raw}")
    print(f"  server_name (parsed)      : {server_name_or_hostname}")
    print(f"  dns_name                  : {realm}")
    print(f"  workgroup                 : {workgroup}")
    print(f"  machine_account_password  : {utils.mask_password(password)}")
    print(f"  dns_servers               : {dns_servers}")
    print(f"  nt_key_cache_enabled      : {nt_key_cache_enabled}")
    print(f"  nt_key_cache_expire       : {nt_key_cache_expire}")

    # validate NT Key cache configuration
    nt_key_cache_enabled = get_boolean_value(nt_key_cache_enabled)

    if nt_key_cache_enabled:
        for i in range(1):
            nt_key_cache_expire, error = get_int_value(nt_key_cache_expire)
            if error is not None:
                print("  NT Key cache: can not parse 'nt_key_cache_expire', cache disabled.")
                nt_key_cache_enabled = False
                break
            if nt_key_cache_expire < 60:
                print(f"  NT key cache: expire value '{nt_key_cache_expire}' too small, set to minimum value: 60")
                nt_key_cache_expire = 60
            if nt_key_cache_expire > 864000:
                print(f"  NT key cache: expire value '{nt_key_cache_expire}' too large, set to maximum value: 864000")
                nt_key_cache_expire = 864000

            ad_old_password_allowed_period, error = get_int_value(ad_old_password_allowed_period)
            if error is not None:
                print(f"  NT Key cache: unable to parse 'ad_old_password_allowed_period', cache disabled.")
                nt_key_cache_enabled = False
                break
            if ad_old_password_allowed_period < 0 or ad_old_password_allowed_period > 99999:
                print(f"  NT Key cache: 'ad_old_password_allowed_period' ranges from 0..99999, cache disabled.")
                nt_key_cache_enabled = False
                break

            ad_account_lockout_threshold, error = get_int_value(ad_account_lockout_threshold)
            if error is not None:
                print("  NT Key cache: can not parse 'ad_account_lockout_threshold', cache disabled.")
                nt_key_cache_enabled = False
                break
            if ad_account_lockout_threshold == 0:
                ad_account_lockout_threshold = 999
                ad_account_lockout_duration = 0
                ad_reset_account_lockout_count_after = 0
                max_allowed_attempts_per_device = 999
                ad_old_password_allowed_period, error = get_int_value(ad_old_password_allowed_period)
                if error is not None: ad_old_password_allowed_period = 0
                break
            if ad_account_lockout_threshold < 2 or ad_account_lockout_threshold > 999:
                print(f"  NT Key cache: 'ad_account_lock_threshold' ranges from 2..999, cache disabled.")
                nt_key_cache_enabled = False
                break

            ad_account_lockout_duration, error = get_int_value(ad_account_lockout_duration)
            if error is not None:
                print(f"  NT Key cache: can not parse 'account_lockout_duration', cache disabled.")
                nt_key_cache_enabled = False
                break
            if ad_account_lockout_duration < 1 or ad_account_lockout_duration > 99999:
                print(f"  NT Key cache: 'ad_account_lockout_duration' ranges from 1..99999, cache disabled.")
                nt_key_cache_enabled = False
                break

            ad_reset_account_lockout_count_after, error = get_int_value(ad_reset_account_lockout_count_after)
            if error is not None:
                print(f"  NT Key cache: can not parse 'ad_reset_account_lockout_after', cache disabled.")
                nt_key_cache_enabled = False
                break
            if ad_reset_account_lockout_count_after < 1 or ad_reset_account_lockout_count_after > 99999:
                print(f"  NT Key cache: 'ad_reset_account_lockout_counter_after' ranges from 1..99999, cache disabled.")
                nt_key_cache_enabled = False
                break
            if ad_reset_account_lockout_count_after > ad_account_lockout_duration:
                s_reset = 'ad_reset_account_lockout_counter_after'
                s_duration = 'ad_account_lockout_duration'
                print(f"  NT Key cache: '{s_reset}' larger than '{s_duration}', cache disabled.")
                nt_key_cache_enabled = False
                break

            max_allowed_attempts_per_device, error = get_int_value(max_allowed_attempts_per_device)
            s_device = 'max_allowed_attempts_per_device'
            s_threshold = 'ad_account_lockout_threshold'
            if error is not None:
                print(f"  NT Key cache: unable to parse '{s_device}', set to '{s_threshold}' by default.")
                max_allowed_attempts_per_device = ad_account_lockout_threshold
                break
            if max_allowed_attempts_per_device < 0 or max_allowed_attempts_per_device > 999:
                print(f"  NT Key cache: '{s_device}' ranges from 0..999, set to '{s_threshold}' by default.")
                break
            if max_allowed_attempts_per_device > ad_account_lockout_threshold:
                print(f"  NT Key cache: '{s_device}' larger than '{s_threshold}', set to '{s_threshold}' by default.")

    if None in (c_db_host, c_db_port, c_db_user, c_db_pass, c_db, c_db_unix_socket):
        print(f"  DB config: Missing settings, NT Key cache will be disabled")
        nt_key_cache_enabled = False

    print("NT Key caching:")
    print(f"  ad_account_lockout_threshold                         : {ad_account_lockout_threshold}")
    print(f"  ad_account_lockout_duration (in minutes)             : {ad_account_lockout_duration}")
    print(f"  ad_reset_account_lockout_counter_after (in minutes)  : {ad_reset_account_lockout_count_after}")
    print(f"  ad_old_password_allowed_period (in minutes)          : {ad_old_password_allowed_period}")
    print(f"  max_allowed_password_attempts_per_device             : {max_allowed_attempts_per_device}")

    global_vars.c_server_name = ad_fqdn
    global_vars.c_realm = realm
    global_vars.c_workgroup = workgroup
    global_vars.c_username = username
    global_vars.c_password = password
    global_vars.c_netbios_name = netbios_name
    global_vars.c_workstation = workstation
    global_vars.c_server_string = server_string
    global_vars.c_domain = domain
    global_vars.c_dns_servers = dns_servers

    global_vars.c_nt_key_cache_enabled = nt_key_cache_enabled
    global_vars.c_nt_key_cache_expire = int(nt_key_cache_expire)

    global_vars.c_ad_account_lockout_threshold = ad_account_lockout_threshold
    global_vars.c_ad_account_lockout_duration = ad_account_lockout_duration
    global_vars.c_ad_reset_account_lockout_counter_after = ad_reset_account_lockout_count_after
    global_vars.c_ad_old_password_allowed_period = ad_old_password_allowed_period
    global_vars.c_max_allowed_password_attempts_per_device = max_allowed_attempts_per_device

    global_vars.c_db_host = c_db_host
    global_vars.c_db_port = c_db_port
    global_vars.c_db_user = c_db_user
    global_vars.c_db_pass = c_db_pass
    global_vars.c_db = c_db
    global_vars.c_db_unix_socket = c_db_unix_socket
