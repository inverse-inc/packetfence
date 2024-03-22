import configparser
import os
import socket
import sys
import time
from configparser import ConfigParser

import config_generator
import global_vars
import utils


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
        password_is_nt_hash = config.get(identifier, 'password_is_nt_hash')

        netbios_name = server_name_or_hostname.upper()
        workstation = server_name_or_hostname.upper()
        server_string = server_name_or_hostname
        domain = workgroup.lower()

        nt_key_cache_enabled = config.get(identifier, 'nt_key_cache_enabled', fallback=False)
        nt_key_cache_expire = config.get(identifier, 'nt_key_cache_expire', fallback=3600)

        if nt_key_cache_enabled and nt_key_cache_expire < 60:
            nt_key_cache_expire = 60  # we set min nt_key_expiration time to 1 min.
    except FileNotFoundError as e:
        print(f"  {conf_path} not found or unreadable. Terminated.")
        sys.exit(1)
    except configparser.Error as e:
        print(f"  Error loading config from domain.conf: {e}. Terminated.")
        sys.exit(1)

    if ad_fqdn == "":
        print("  'ad_fqdn' is not set. NTLM Auth API wasn't able to start")
        exit(1)

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
                exit(1)
    else:
        if utils.is_ipv4(ad_server):
            config_generator.generate_hosts_entry(ad_server, ad_fqdn)
            print(f"DNS servers not available, Starting using static hosts entry: {ad_server} {ad_fqdn}.")
        else:
            print("Unable to start NTLM Auth API. 'ad_server' must be a valid IPv4 if DNS servers not specified.")
            exit(1)

    global_vars.c_server_name = ad_fqdn
    global_vars.c_realm = realm
    global_vars.c_workgroup = workgroup
    global_vars.c_username = username
    global_vars.c_password = password
    global_vars.c_netbios_name = netbios_name
    global_vars.c_workstation = workstation
    global_vars.c_server_string = server_string
    global_vars.c_domain = domain
