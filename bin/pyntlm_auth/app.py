import binascii
import configparser
import datetime
import hashlib
import json
import os
import re
import socket
import sys
import threading
import time
from configparser import ConfigParser
from http import HTTPStatus
from threading import Thread

import pymysql
import sdnotify
from flask import Flask, request, g
from flaskext.mysql import MySQL
from samba import param, NTSTATUSError, ntstatus
from samba.credentials import Credentials, DONT_USE_KERBEROS
from samba.dcerpc import netlogon
from samba.dcerpc.misc import SEC_CHAN_WKSTA
from samba.dcerpc.netlogon import (netr_Authenticator, MSV1_0_ALLOW_WORKSTATION_TRUST_ACCOUNT, MSV1_0_ALLOW_MSVCHAPV2)

import utils
import config_generator


def init_secure_connection():
    global machine_cred
    global secure_channel_connection
    global netbios_name
    global realm
    global server_string
    global workgroup
    global workstation
    global password
    global domain
    global username
    global server_name
    lp = param.LoadParm()

    try:
        config_generator.generate_empty_conf()
        lp.load("/root/default.conf")
    except KeyError:
        raise KeyError("SMB_CONF_PATH not set")

    lp.set('netbios name', netbios_name)
    lp.set('realm', realm)
    lp.set('server string', server_string)
    lp.set('workgroup', workgroup)

    machine_cred = Credentials()

    machine_cred.guess(lp)
    machine_cred.set_secure_channel_type(SEC_CHAN_WKSTA)
    machine_cred.set_kerberos_state(DONT_USE_KERBEROS)

    machine_cred.set_workstation(workstation)
    machine_cred.set_username(username)
    machine_cred.set_password(password)

    machine_cred.set_password_will_be_nt_hash(True)
    machine_cred.set_domain(domain)

    error_code = 0
    error_message = ""
    try:
        secure_channel_connection = netlogon.netlogon(f"ncacn_np:{server_name}[schannel,seal]", lp, machine_cred)
    except NTSTATUSError as e:
        error_code = e.args[0]
        error_message = e.args[1]
        print(f"Error in init secure connection: NT_Error, error_code={error_code}, error_message={error_message}.")
        print("Parameter used in establish secure channel are:")
        print(f"  lp.netbios_name: {netbios_name}")
        print(f"  lp.realm: {realm}")
        print(f"  lp.server_string: {server_string}")
        print(f"  lp.workgroup: {workgroup}")
        print(f"  workstation: {workstation}")
        print(f"  username: {username}")
        print(f"  password: {utils.mask_password(password)}")
        print(f"  set_NT_hash_flag: True")
        print(f"  domain: {domain}")
        print(f"  server_name(ad_fqdn): {server_name}\n")

        # some common errors we already know to avoid reconnect:
        # ntstatus.NT_STATUS_ACCESS_DENIED - usually wrong password
        # ntstatus.NT_STATUS_NO_TRUST_SAM_ACCOUNT - machine account doesn't exist
        # ntstatus.NT_STATUS_OBJECT_NAME_NOT_FOUND - usually AD FQDN not resolved
        # ntstatus.NT_STATUS_NO_SUCH_DOMAIN
        # ntstatus.NT_STATUS_NO_MEMORY (0xC0000017) - usually windows AD is shutdown
        # ---- error in init secure connection: NT_Error, error_code=3221225653, error_message={Device Timeout} The specified I/O operation on %hs was not completed before the time-out period expired.
    except Exception as e:
        error_code = e.args[0]
        error_message = e.args[1]
        print(f"Error in init secure connection: General, error_code={error_code}, error_message={error_message}.")
    return secure_channel_connection, machine_cred, error_code, error_message


def get_secure_channel_connection():
    global machine_cred
    global secure_channel_connection
    global connection_id
    global reconnect_id
    global connection_last_active_time
    global lock

    with lock:
        if secure_channel_connection is None or machine_cred is None or (
                reconnect_id != 0 and connection_id <= reconnect_id) or (
                datetime.datetime.now() - connection_last_active_time).total_seconds() > 5 * 60:
            secure_channel_connection, machine_cred, error_code, error_message = init_secure_connection()
            connection_id += 1
            reconnect_id = connection_id if error_code != 0 else 0
            connection_last_active_time = datetime.datetime.now()
            return secure_channel_connection, machine_cred, connection_id, error_code, error_message
        else:
            connection_last_active_time = datetime.datetime.now()
            return secure_channel_connection, machine_cred, connection_id, 0, ""


def ntlm_connect_handler():
    global machine_cred
    global secure_channel_connection
    global connection_id
    global reconnect_id

    with lock:
        reconnect_id = connection_id

    secure_channel_connection, machine_cred, connection_id, error_code, error_message = get_secure_channel_connection()

    if error_code == ntstatus.NT_STATUS_ACCESS_DENIED:
        return "Test machine account failed. Access Denied", HTTPStatus.UNAUTHORIZED
    if error_code != 0:
        return "Error while establishing secure channel connection: " + error_message, HTTPStatus.INTERNAL_SERVER_ERROR

    return "OK", HTTPStatus.OK


def test_password_handler():
    data = request.get_json()

    if data is None:
        return 'No JSON payload found in request', HTTPStatus.BAD_REQUEST
    if 'password' not in data:
        return 'Invalid JSON payload format, missing required key: password', HTTPStatus.UNPROCESSABLE_ENTITY

    test_password = data['password'].strip()

    if re.search(r'^[a-fA-F0-9]{32}$', test_password):
        nt_hash = test_password
    else:
        nt4_digest = hashlib.new('md4', test_password.encode('utf-16le')).digest()
        nt_hash = binascii.hexlify(nt4_digest).decode('utf-8')

    global password
    global machine_cred
    global secure_channel_connection
    global connection_id
    global reconnect_id

    password = nt_hash

    with lock:
        reconnect_id = connection_id

    secure_channel_connection, machine_cred, connection_id, error_code, error_message = get_secure_channel_connection()

    if error_code == ntstatus.NT_STATUS_ACCESS_DENIED:
        return "Test machine account failed. Access Denied", HTTPStatus.UNAUTHORIZED
    if error_code != 0:
        return "Error while establishing secure channel connection: " + error_message, HTTPStatus.INTERNAL_SERVER_ERROR

    return "OK", HTTPStatus.OK


def transitive_login(account_username, challenge, nt_response):
    global machine_cred
    global secure_channel_connection
    global connection_id
    global reconnect_id
    global server_name
    global domain
    global workstation
    secure_channel_connection, machine_cred, connection_id, error_code, error_message = get_secure_channel_connection()
    if error_code != 0:
        return "Error while establishing secure channel connection: " + error_message, HTTPStatus.INTERNAL_SERVER_ERROR

    with lock:
        try:
            auth = machine_cred.new_client_authenticator()
        except Exception as e:
            # usually we won't reach this if machine cred is authenticated successfully. Just in case.
            reconnect_id = connection_id
            return "Error in creating authenticator.", HTTPStatus.INTERNAL_SERVER_ERROR

        logon_level = netlogon.NetlogonNetworkTransitiveInformation
        validation_level = netlogon.NetlogonValidationSamInfo4

        netr_flags = 0
        current = netr_Authenticator()
        current.cred.data = [x if isinstance(x, int) else ord(x) for x in auth["credential"]]
        current.timestamp = auth["timestamp"]

        subsequent = netr_Authenticator()

        challenge = binascii.unhexlify(challenge)
        response = binascii.unhexlify(nt_response)

        logon = netlogon.netr_NetworkInfo()
        logon.challenge = [x if isinstance(x, int) else ord(x) for x in challenge]
        logon.nt = netlogon.netr_ChallengeResponse()
        logon.nt.data = [x if isinstance(x, int) else ord(x) for x in response]
        logon.nt.length = len(response)

        logon.identity_info = netlogon.netr_IdentityInfo()
        logon.identity_info.domain_name.string = domain
        logon.identity_info.account_name.string = account_username
        logon.identity_info.workstation.string = workstation
        logon.identity_info.parameter_control = MSV1_0_ALLOW_WORKSTATION_TRUST_ACCOUNT | MSV1_0_ALLOW_MSVCHAPV2

        try:
            result = secure_channel_connection.netr_LogonSamLogonWithFlags(server_name, workstation, current,
                                                                           subsequent,
                                                                           logon_level, logon, validation_level,
                                                                           netr_flags)
            (return_auth, info, foo, bar) = result

            nt_key = [x if isinstance(x, str) else hex(x)[2:].zfill(2) for x in info.base.key.key]
            nt_key_str = ''.join(nt_key)
            nt_key_str = "NT_KEY: " + nt_key_str
            print(f"  Successfully authenticated '{account_username}', NT_KEY is: '{utils.mask_password(nt_key_str)}'.")
            return nt_key_str.encode("utf-8"), HTTPStatus.OK
        except NTSTATUSError as e:
            nt_error_code = e.args[0]
            nt_error_message = e.args[1]

            if nt_error_code == ntstatus.NT_STATUS_NO_SUCH_USER:
                return nt_error_message, HTTPStatus.NOT_FOUND
            if nt_error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
                return nt_error_message, HTTPStatus.UNAUTHORIZED
            if nt_error_code == ntstatus.NT_STATUS_ACCOUNT_LOCKED_OUT:  # we should stop retrying after failures
                return nt_error_message, HTTPStatus.LOCKED
            if nt_error_code == ntstatus.NT_STATUS_LOGIN_WKSTA_RESTRICTION:
                return nt_error_message, HTTPStatus.UNAUTHORIZED
            if nt_error_code == ntstatus.NT_STATUS_ACCOUNT_DISABLED:
                return nt_error_message, HTTPStatus.UNAUTHORIZED

            print(f"  Failed while authenticating user: '{account_username}' with NT Error: {e}.")
            reconnect_id = connection_id
            return f"NT Error: {e}", HTTPStatus.INTERNAL_SERVER_ERROR
        except Exception as e:
            reconnect_id = connection_id
            print(f"  Failed while authenticating user: '{account_username}' with General Error: {e}.")
            return "Error handling request", HTTPStatus.INTERNAL_SERVER_ERROR


def build_cache_struct(domain, mac, account, nt_key, dirty, bad_password_count, expires_at, last_login):
    cache = {
        "domain": domain,
        "mac": mac,
        "account": account,
        "nt_key": nt_key,
        "dirty": dirty,
        "bad_password_count": bad_password_count,
        "expires_at": expires_at,
        "last_login": last_login
    }
    return cache


def build_cache_key(domain, account_username, mac):
    cache_key_prefix = "nt_key_cache"
    mac = mac.strip()
    if mac == '':
        return f"{cache_key_prefix}:{domain}:{account_username}"
    else:
        mac = mac.replace(':', '-')
        return f"{cache_key_prefix}:{domain}:{account_username}:{mac}"


def update_cache_entry(key, value, expires_at):
    query = "INSERT INTO `chi_cache` (`key`, `value`, `expires_at`) VALUES (%s, %s, %s) " \
            "ON DUPLICATE KEY UPDATE `value` = %s"
    if hasattr(g, 'db'):
        g.db.execute(query, key, value, expires_at, value)


def expires():
    return datetime.datetime.now().timestamp() + 3600


def now():
    return datetime.datetime.now().timestamp()


def invalid_cache():
    return


def ntlm_auth_handler():
    global nt_key_cache_enabled
    global nt_key_cache_expire
    global nt_key_cache
    global domain

    try:
        required_keys = {'username', 'mac', 'request-nt-key', 'challenge', 'nt-response'}

        data = request.get_json()
        if data is None:
            return 'No JSON payload found in request', HTTPStatus.BAD_REQUEST
        for required_key in required_keys:
            if required_key not in data:
                return f'Invalid payload format, missing required key {required_key}', HTTPStatus.UNPROCESSABLE_ENTITY

        mac = data['mac']
        account_username = data['username']
        challenge = data['challenge']
        nt_response = data['nt-response']

    except Exception as e:
        return f"Error processing JSON payload, {str(e)}", HTTPStatus.INTERNAL_SERVER_ERROR

    if nt_key_cache_enabled:
        print(f"  NT Key cache is enabled.")
        cache_key_root = build_cache_key(domain, account_username, '')
        cache_key_device = build_cache_key(domain, account_username, mac)

        print(f"authoritative cache entry: {cache_key_root}")
        print(f"device cache entry: {cache_key_device}")

        if hasattr(g, 'db'):
            query = "SELECT `key`, `value`, `expires_at` FROM `chi_cache` WHERE `key` = %s LIMIT 1"
            g.db.execute(query, cache_key_root)
            cache_entry_root = g.db.fetchone()
            g.db.execute(query, cache_key_device)
            cache_entry_device = g.db.fetchone()

            if cache_entry_root is None and cache_entry_device is None:
                resp_body, resp_code = transitive_login(account_username=account_username, challenge=challenge,
                                                        nt_response=nt_response)
                if resp_code == HTTPStatus.OK:
                    pk_root = build_cache_key(domain, account_username, '')
                    pk_device = build_cache_key(domain, account_username, mac)

                    value = json.dumps(build_cache_struct(
                        domain=domain,
                        mac=mac,
                        nt_key=resp_body,
                        dirty=False,
                        bad_password_count=0,
                        expires_at=int(datetime.datetime.now().timestamp()) + 3600,
                        last_login=int(datetime.datetime.now().timestamp())
                    ))
                    update_cache_entry(pk_root, value, expires())
                else:
                    if resp_code == HTTPStatus.UNAUTHORIZED:
                        invalid_cache()

            if cache_entry_root is None and cache_entry_device is not None:
                print("  **** root entry x, device entry y")
            if cache_entry_root is not None and cache_entry_device is None:
                print("  **** root entry y, device entry x")
                cache_value = json.loads(cache_entry_root['value'])
        return '', HTTPStatus.OK
    else:
        print(f"  NT key cache is disabled.")
        resp_body, resp_code = transitive_login(account_username=account_username, challenge=challenge,
                                                nt_response=nt_response)
        return resp_body, resp_code


def ping_handler():
    return "pong", HTTPStatus.OK


def sd_notify():
    n = sdnotify.SystemdNotifier()
    n.notify("READY=1")
    count = 1
    while True:
        print("Running... {}".format(count))
        n.notify("STATUS=Count is {}".format(count))
        count += 1
        time.sleep(30)


def api():
    global netbios_name
    global realm
    global server_string
    global workgroup
    global workstation
    global domain
    global password
    global username
    global server_name

    global nt_key_cache_enabled
    global nt_key_cache_expire
    global nt_key_cache

    conf_path = "/usr/local/pf/conf/domain.conf"
    listen_port = os.getenv("LISTEN")
    identifier = os.getenv("IDENTIFIER")

    db_host = os.getenv("DB_HOST")
    db_port = os.getenv("DB_PORT")
    db_user = os.getenv("DB_USER")
    db_pass = os.getenv("DB_PASS")
    db = os.getenv("DB")

    print("NTLM auth api starts with the following parameters:")
    print(f"LISTEN = {listen_port}")
    print(f"IDENTIFIER = {identifier}.")
    print(f"DB {db_user}:***@{db_host}:{db_port}/{db}")

    if identifier == "" or listen_port == "":
        print("Unable to start NTLM auth API: Missing key arguments: 'IDENTIFIER' or 'LISTEN'.")

    config = ConfigParser(interpolation=None)
    try:
        with open(conf_path, 'r') as file:
            config.read_file(file)

        if identifier in config:
            server_name_or_hostname = config.get(identifier, 'server_name')
            server_name_raw = server_name_or_hostname

            if server_name_or_hostname.strip() == "%h":
                server_name_or_hostname = socket.gethostname().split(".")[0]

            ad_fqdn = config.get(identifier, 'ad_fqdn')
            ad_server = config.get(identifier, 'ad_server')
            netbios_name = server_name_or_hostname.upper()
            realm = config.get(identifier, 'dns_name')
            server_string = server_name_or_hostname
            workgroup = config.get(identifier, 'workgroup')
            workstation = server_name_or_hostname.upper()
            username = server_name_or_hostname.upper() + "$"
            password = config.get(identifier, 'machine_account_password')
            password_is_nt_hash = config.get(identifier, 'password_is_nt_hash')
            domain = config.get(identifier, 'workgroup').lower()
            dns_servers = config.get(identifier, 'dns_servers')
            nt_key_cache_enabled = config.get(identifier, 'nt_key_cache_enabled', fallback=False)
            nt_key_cache_expire = config.get(identifier, 'nt_key_cache_expire', fallback=3600)

            if nt_key_cache_enabled and nt_key_cache_expire < 60:
                nt_key_cache_expire = 60  # we set min nt_key_expiration time to 1 min.
        else:
            print(f"Section {identifier} does not exist in the config file.")
            sys.exit(1)
    except FileNotFoundError as e:
        print(f"Specified config file not found in {conf_path}.")
        sys.exit(1)
    except configparser.Error as e:
        print(f"Error reading config file: {e}.")
        sys.exit(1)

    if ad_fqdn == "":
        print("Failed to start NTLM auth API: ad_fqdn is not set.\n")
        exit(1)

    print("NTLM auth API start with following domain.conf parameters:")
    print(f"  ad_fqdn: {ad_fqdn}")
    print(f"  ad_server: {ad_server}")
    print(f"  server_name: {server_name_raw}")
    print(f"  server_name (parsed): {server_name_or_hostname}")
    print(f"  dns_name: {realm}")
    print(f"  workgroup: {workgroup}")
    print(f"  machine_account_password: {utils.mask_password(password)}")
    print(f"  dns_servers: {dns_servers}.")
    print(f"  nt_key_cache_enabled: {nt_key_cache_enabled}")
    print(f"  nt_key_cache_expire: {nt_key_cache_expire}")

    if dns_servers != "":
        config_generator.generate_resolv_conf(realm, dns_servers)
        time.sleep(1)
        ip, err_msg = utils.dns_lookup(ad_fqdn, "")
        if ip != "" and err_msg == "":
            print(f"AD FQDN: {ad_fqdn} resolved with IP: {ip}.")
        else:
            if utils.is_ipv4(
                    ad_server):  # plan B: if it's not resolved then we use the static IP provided in the profile
                print(
                    f"AD FQDN resolve failed. Starting NTLM auth API using static hosts entry: {ad_server} {ad_fqdn}.")
                config_generator.generate_hosts_entry(ad_server, ad_fqdn)
            else:
                print("Failed to retrieve IP address of AD server. Terminated.")
                exit(1)
    else:
        if utils.is_ipv4(ad_server):
            config_generator.generate_hosts_entry(ad_server, ad_fqdn)
            print(f"Starting NTLM auth API using static hosts entry: {ad_server} {ad_fqdn}.")
        else:
            print("Failed to start NTLM auth API. 'ad_server' is required when DNS servers are unavailable.")
            exit(1)

    server_name = ad_fqdn

    app = Flask(__name__)

    app.config['MYSQL_DATABASE_HOST'] = db_host
    app.config['MYSQL_DATABASE_PORT'] = int(db_port)
    app.config['MYSQL_DATABASE_USER'] = db_user
    app.config['MYSQL_DATABASE_PASSWORD'] = db_pass
    app.config['MYSQL_DATABASE_DB'] = db
    app.config['MYSQL_DATABASE_CHARSET'] = 'utf8mb4'

    mysql = MySQL(autocommit=True, cursorclass=pymysql.cursors.DictCursor)
    mysql.init_app(app)

    @app.before_request
    def before_request():
        g.db = mysql.get_db().cursor()
        print(f"  ----db is: {g.db}")

    @app.teardown_request
    def teardown_request(exception=None):
        if hasattr(g, 'db'):
            print("  ---- db on closing...")
            g.db.close()

    app.route('/ntlm/auth', methods=['POST'])(ntlm_auth_handler)
    app.route('/ntlm/connect', methods=['GET'])(ntlm_connect_handler)
    app.route('/ntlm/connect', methods=['POST'])(test_password_handler)
    app.route('/ping', methods=['GET'])(ping_handler)

    app.run(threaded=True, host='0.0.0.0', port=int(listen_port))


if __name__ == '__main__':
    machine_cred = None
    secure_channel_connection = None
    connection_id = 1
    reconnect_id = 0
    connection_last_active_time = datetime.datetime.now()
    lock = threading.Lock()
    netbios_name = None
    realm = None
    server_string = None
    workgroup = None
    workstation = None
    password = None
    domain = None
    username = None
    server_name = None
    nt_key_cache_enabled = None
    nt_key_cache_expire = None
    nt_key_cache = None

    # Run tasks concurrently using multithreading
    t1 = Thread(target=api)
    t2 = Thread(target=sd_notify)
    t1.start()
    t2.start()
    t1.join()
    t2.join()
