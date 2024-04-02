import configparser
import os
import socket
import sys
import time
from configparser import ConfigParser

import config_generator
import global_vars
import utils


def get_boolean_value(v):
    false_dict = ('', '0', 'no', 'n', 'false', 'off', 'disabled')

    if v is None:
        return False

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
    conf_path = "/usr/local/pf/conf/domain.conf"

    global_vars.c_listen_port = os.getenv("LISTEN")
    global_vars.c_domain_identifier = os.getenv("IDENTIFIER")
    global_vars.c_db_host = os.getenv("DB_HOST")
    global_vars.c_db_port = os.getenv("DB_PORT")
    global_vars.c_db_user = os.getenv("DB_USER")
    global_vars.c_db_pass = os.getenv("DB_PASS")
    global_vars.c_db = os.getenv("DB")

    print("NTLM Auth API starts with the following parameters:")
    print(f"  LISTEN = {global_vars.c_listen_port}")
    print(f"  IDENTIFIER = {global_vars.c_domain_identifier}.")
    print(
        f"  {global_vars.c_db_user}:{utils.mask_password(global_vars.c_db_pass)}@{global_vars.c_db_host}:{global_vars.c_db_port}/{global_vars.c_db}")

    if global_vars.c_domain_identifier == "" or global_vars.c_listen_port == "":
        print("Unable to start NTLM Auth API: Missing 'IDENTIFIER' or 'LISTEN'")
        exit(1)

    config = ConfigParser(interpolation=None)
    print(f"Load domain config from {conf_path}")
    try:
        with open(conf_path, 'r') as file:
            config.read_file(file)
        identifier = global_vars.c_domain_identifier
        if identifier not in config:
            print(f"  Section {identifier} does not exist in domain.conf. Terminated.")
            sys.exit(1)

        server_name_raw = config.get(identifier, 'server_name')
        server_name_or_hostname = server_name_raw
        if server_name_raw.strip() == "%h":
            server_name_or_hostname = socket.gethostname().split(".")[0]

        ad_fqdn = config.get(identifier, 'ad_fqdn')
        ad_server = config.get(identifier, 'ad_server')
        realm = config.get(identifier, 'dns_name')
        workgroup = config.get(identifier, 'workgroup')
        dns_servers = config.get(identifier, 'dns_servers')
        username = server_name_or_hostname.upper() + "$"
        password = config.get(identifier, 'machine_account_password')
        password_is_nt_hash = get_boolean_value(config.get(identifier, 'password_is_nt_hash'))

        netbios_name = server_name_or_hostname.upper()
        workstation = server_name_or_hostname.upper()
        server_string = server_name_or_hostname
        domain = workgroup.lower()

        nt_key_cache_enabled = get_boolean_value(config.get(identifier, 'nt_key_cache_enabled', fallback=False))
        nt_key_cache_expire = config.get(identifier, 'nt_key_cache_expire', fallback=3600)

        ad_account_lockout_threshold = config.get(identifier, 'ad_account_lockout_threshold', fallback='0')
        ad_account_lockout_duration = config.get(identifier, 'ad_account_lockout_duration', fallback=None)
        ad_reset_account_lockout_counter_after = config.get(identifier, 'ad_reset_account_lockout_counter_after',
                                                            fallback=None)
        ad_old_password_allowed_period = config.get(identifier, 'ad_old_password_allowed_period', fallback=None)

        max_allowed_password_attempts_per_device = config.get(identifier, 'max_allowed_password_attempts_per_device', fallback=None)

        nt_key_cache_expire, error = get_int_value(nt_key_cache_expire)
        if error is not None:
            print("  Error while applying NT key cache settings: can not parse 'nt_key_cache_expire'")
            sys.exit(1)

        if nt_key_cache_enabled and nt_key_cache_expire < 60:
            print("  NT key cache expire set to minimum value: 60")
            nt_key_cache_expire = 60  # we set min nt_key_expiration time to 1 min.

        if ad_account_lockout_threshold is None or ad_account_lockout_threshold.strip() == '':
            ad_account_lockout_threshold = 0
        else:
            ad_account_lockout_threshold, error = get_int_value(ad_account_lockout_threshold)
            if error is not None:
                print("  Error while applying NT key cache settings: can not parse 'ad_account_lockout_threshold'")
                sys.exit(1)

        if ad_account_lockout_threshold == 0:
            ad_account_lockout_duration = None
            ad_reset_account_lockout_counter_after = None
            max_allowed_password_attempts_per_device = None
        else:
            if ad_account_lockout_threshold < 0 or ad_account_lockout_threshold > 999:
                print(f"  Error applying NT key cache settings: 'ad_account_lock_threshold' ranges from 0..999")
                sys.exit(1)

            if ad_account_lockout_duration is None or ad_account_lockout_duration.strip() == '':
                ad_account_lockout_duration = None
            else:
                ad_account_lockout_duration, error = get_int_value(ad_account_lockout_duration)
                if error is not None:
                    print(f"  Error applying NT key cache settings: unable to parse 'ad_account_lockout_duration'")
                    sys.exit(1)
                if ad_account_lockout_duration < 0 or ad_account_lockout_duration > 99999:
                    print(f"  Error applying NT key cache settings: 'ad_account_lockout_duration' ranges from 0..99999")
                    sys.exit(1)

            if ad_reset_account_lockout_counter_after is None or ad_reset_account_lockout_counter_after.strip() == '':
                ad_reset_account_lockout_counter_after = None
            else:
                ad_reset_account_lockout_counter_after, error = get_int_value(ad_reset_account_lockout_counter_after)
                if error is not None:
                    print(f"  Error applying NT key cache settings: unable to parse 'ad_reset_account_lockout_after'")
                    sys.exit(1)
                if ad_reset_account_lockout_counter_after < 0 or ad_reset_account_lockout_counter_after > 99999:
                    print(f"  Error applying NT key cache settings: 'ad_reset_account_lockout_counter_after' ranges from 0..99999")
                    sys.exit(1)

            if ad_old_password_allowed_period is None or ad_old_password_allowed_period.strip() == '':
                ad_old_password_allowed_period = 60
            else:
                ad_old_password_allowed_period, error = get_int_value(ad_old_password_allowed_period)
                if error is not None:
                    print(f"  Error applying NT key cache settings: unable to parse 'ad_old_password_allowed_period'")
                    sys.exit(1)
                if ad_old_password_allowed_period < 0 or ad_old_password_allowed_period > 99999:
                    print(f"  Error while applying NT key cache settings: 'ad_old_password_allowed_period' ranges from 0..99999")
                    sys.exit(1)

            if ad_account_lockout_threshold > 0 and ad_account_lockout_duration > 0:
                if ad_reset_account_lockout_counter_after > ad_account_lockout_duration:
                    print(f"  Error applying NT key cache settings: 'ad_reset_account_lockout_counter_after' must <= 'ad_account_lockout_duration'")
                    sys.exit(1)

            if max_allowed_password_attempts_per_device is None or max_allowed_password_attempts_per_device.strip() == '':
                max_allowed_password_attempts_per_device = None
            else:
                max_allowed_password_attempts_per_device, error = get_int_value(max_allowed_password_attempts_per_device)
                if error is not None:
                    print(f"  Error applying NT key cache settings: unable to parse 'max_allowed_password_attempts_per_device'")
                    sys.exit(1)
                if max_allowed_password_attempts_per_device < 0 or max_allowed_password_attempts_per_device > 999:
                    print(f"  Error while applying NT key cache settings: 'max_allowed_password_attempts_per_device' ranges from 0..999")
                    sys.exit(1)
                if max_allowed_password_attempts_per_device > ad_account_lockout_threshold:
                    print(f"  Error while applying NT key cache settings: 'max_allowed_password_attempts_per_device', must less or equal than ad_account_lockout_threshold")

    except FileNotFoundError as e:
        print(f"  {conf_path} not found or unreadable. Terminated.")
        sys.exit(1)
    except configparser.Error as e:
        print(f"  Error loading config from domain.conf: {e}. Terminated.")
        sys.exit(1)

    if ad_fqdn == "":
        print("  'ad_fqdn' is not set. NTLM Auth API wasn't able to start")
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

    if dns_servers != "":
        config_generator.generate_resolv_conf(realm, dns_servers)
        time.sleep(1)
        ip, err_msg = utils.dns_lookup(ad_fqdn, "")
        if ip != "" and err_msg == "":
            print(f"AD FQDN: {ad_fqdn} resolved with IP: {ip}.")
        else:
            if utils.is_ipv4(ad_server):  # if it's not resolvable, we use static IP provided in domain.conf
                print(f"AD FQDN resolving failed. Starting with static hosts entry: {ad_server} {ad_fqdn}.")
                config_generator.generate_hosts_entry(ad_server, ad_fqdn)
            else:
                print("Failed to retrieve IP address of AD server. Terminated.")
                sys.exit(1)
    else:
        if utils.is_ipv4(ad_server):
            config_generator.generate_hosts_entry(ad_server, ad_fqdn)
            print(f"DNS servers not available, Starting using static hosts entry: {ad_server} {ad_fqdn}.")
        else:
            print("Unable to start NTLM Auth API. 'ad_server' must be a valid IPv4 if DNS servers not specified.")
            sys.exit(1)

    print("NT Key caching:")
    print(f"  ad_account_lockout_threshold                         : {ad_account_lockout_threshold}")
    print(f"  ad_account_lockout_duration (in minutes)             : {ad_account_lockout_duration}")
    print(f"  ad_reset_account_lockout_counter_after (in minutes)  : {ad_reset_account_lockout_counter_after}")
    print(f"  ad_old_password_allowed_period (in minutes)          : {ad_old_password_allowed_period}")
    print(f"  max_allowed_password_attempts_per_device             : {max_allowed_password_attempts_per_device}")

    global_vars.c_server_name = ad_fqdn
    global_vars.c_realm = realm
    global_vars.c_workgroup = workgroup
    global_vars.c_username = username
    global_vars.c_password = password
    global_vars.c_netbios_name = netbios_name
    global_vars.c_workstation = workstation
    global_vars.c_server_string = server_string
    global_vars.c_domain = domain

    global_vars.c_nt_key_cache_enabled = int(nt_key_cache_enabled)
    global_vars.c_nt_key_cache_expire = int(nt_key_cache_expire)

    global_vars.c_ad_account_lockout_threshold = ad_account_lockout_threshold
    global_vars.c_ad_account_lockout_duration = ad_account_lockout_duration
    global_vars.c_ad_reset_account_lockout_counter_after = ad_reset_account_lockout_counter_after
    global_vars.c_ad_old_password_allowed_period = ad_old_password_allowed_period
    global_vars.c_max_allowed_password_attempts_per_device = max_allowed_password_attempts_per_device
