import binascii
import configparser
import datetime
import hashlib
import os
import re
import socket
import sys
import threading
import time
import sdnotify
from threading import Thread
from configparser import ConfigParser
from http import HTTPStatus

import dns.resolver
from flask import Flask, request
from samba import param, NTSTATUSError, ntstatus
from samba.credentials import Credentials, DONT_USE_KERBEROS
from samba.dcerpc import netlogon
from samba.dcerpc.misc import SEC_CHAN_WKSTA
from samba.dcerpc.netlogon import (netr_Authenticator)


# simplified IPv4 validator.
def is_ipv4(address):
    ipv4_pattern = re.compile(r'^(\d{1,3}\.){3}\d{1,3}$')
    return bool(ipv4_pattern.match(address))


def mask_password(password):
    if len(password) < 4:
        return '*' * len(password)
    else:
        return password[:2] + '*' * (len(password) - 4) + password[-2:]


def dns_lookup(hostname, dns_server):
    if dns_server != "":
        resolver = dns.resolver.Resolver(configure=False)
        resolver.nameservers = dns_server.split(",")
    try:
        answers = dns.resolver.resolve(hostname, 'A')
        for answer in answers:
            return answer.address, ""
    except dns.resolver.NXDOMAIN:
        return "", "NXDOMAIN"
    except dns.exception.DNSException as e:
        return "", e.args[1]


def generate_empty_conf():
    with open('/root/default.conf', 'w') as file:
        file.write("\n")


def generate_resolv_conf(dns_name, dns_servers_string):
    with open('/etc/resolv.conf', 'w') as file:
        file.write(f"\n")
        file.write(f"search {dns_name}\n")
        file.write("\n")
        file.write("options timeout:1\n")
        file.write("options attempts:1\n")
        file.write("\n")

        dns_servers = dns_servers_string.split(",")
        for dns_server in dns_servers:
            file.write(f"nameserver {dns_server}\n")
        file.write("\n")


def generate_hosts_entry(ip, hostname):
    with open('/etc/hosts', 'a') as file:
        file.write(f"\n")
        file.write(f"{ip}    {hostname}")
        file.write("\n")


def init_secure_connection():
    global machine_cred
    global secure_channel_connection
    lp = param.LoadParm()

    try:
        generate_empty_conf()
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
        secure_channel_connection = netlogon.netlogon("ncacn_np:%s[schannel,seal]" % server_name, lp, machine_cred)
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
        print(f"  password: {mask_password(password)}")
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


def ntlm_auth_handler():
    global machine_cred
    global secure_channel_connection
    global connection_id
    global reconnect_id

    try:
        data = request.get_json()

        if data is None:
            return 'No JSON payload found in request', HTTPStatus.BAD_REQUEST
        if 'username' not in data or 'request-nt-key' not in data or 'challenge' not in data or 'nt-response' not in data:
            return 'Invalid JSON payload format, missing required keys', HTTPStatus.UNPROCESSABLE_ENTITY

        account_username = data['username']
        challenge = data['challenge']
        nt_response = data['nt-response']

    except Exception as e:
        return f"Error processing JSON payload, {e.args[1]}", HTTPStatus.INTERNAL_SERVER_ERROR

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

        try:
            result = secure_channel_connection.netr_LogonSamLogonWithFlags(server_name, workstation, current,
                                                                           subsequent,
                                                                           logon_level, logon, validation_level,
                                                                           netr_flags)
            (return_auth, info, foo, bar) = result

            nt_key = [x if isinstance(x, str) else hex(x)[2:] for x in info.base.key.key]
            nt_key_str = ''.join(nt_key)
            nt_key_str = "NT_KEY: " + nt_key_str
            print(f"  Successful authenticated '{account_username}', NT_KEY is: '{mask_password(nt_key_str)}'.")
            return nt_key_str.encode("utf-8")
        except NTSTATUSError as e:
            nt_error_code = e.args[0]
            nt_error_message = e.args[1]

            if nt_error_code == ntstatus.NT_STATUS_NO_SUCH_USER:
                return nt_error_message, HTTPStatus.NOT_FOUND
            if nt_error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
                return nt_error_message, HTTPStatus.UNAUTHORIZED
            if nt_error_code == ntstatus.NT_STATUS_ACCOUNT_LOCKED_OUT:  # we should stop retrying after failures, then it will probably lock the user.
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
    machine_cred = None
    secure_channel_connection = None
    connection_id = 1
    reconnect_id = 0
    connection_last_active_time = datetime.datetime.now()
    lock = threading.Lock()

    conf_path = "/usr/local/pf/conf/domain.conf"
    listen_port = os.getenv("LISTEN")
    identifier = os.getenv("IDENTIFIER")

    print("NTLM auth api starts with the following parameters:")
    print(f"LISTEN = {listen_port}")
    print(f"IDENTIFIER = {identifier}.")

    if identifier == "" or listen_port == "":
        print("Unable to start NTLM auth API: Missing key arguments: 'IDENTIFIER' or 'LISTEN'.")

    config = ConfigParser()
    try:
        with open(conf_path, 'r') as file:
            config.read_file(file)

        if identifier in config:
            server_name_or_hostname = config.get(identifier, 'server_name')
            server_name_raw = server_name_or_hostname

            if server_name_or_hostname.strip() == "%h":
                server_name_or_hostname = socket.gethostname()

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
    print(f"  machine_account_password: {mask_password(password)}")
    print(f"  dns_servers: {dns_servers}.")

    if dns_servers != "":
        generate_resolv_conf(realm, dns_servers)
        time.sleep(1)
        ip, err_msg = dns_lookup(ad_fqdn, "")
        if ip != "" and err_msg == "":
            print(f"AD FQDN: {ad_fqdn} resolved with IP: {ip}.")
        else:
            if is_ipv4(ad_server):  # plan B: if it's not resolved then we use the static IP provided in the profile
                print(f"AD FQDN resolve failed. Starting NTLM auth API using static hosts entry: {ad_server} {ad_fqdn}.")
                generate_hosts_entry(ad_server, ad_fqdn)
            else:
                print("Failed to retrieve IP address of AD server. Terminated.")
                exit(1)
    else:
        if is_ipv4(ad_server):
            generate_hosts_entry(ad_server, ad_fqdn)
            print(f"Starting NTLM auth API using static hosts entry: {ad_server} {ad_fqdn}.")
        else:
            print("Failed to start NTLM auth API. 'ad_server' is required when DNS servers are unavailable.")
            exit(1)

    server_name = ad_fqdn

    app = Flask(__name__)
    app.route('/ntlm/auth', methods=['POST'])(ntlm_auth_handler)
    app.route('/ntlm/connect', methods=['GET'])(ntlm_connect_handler)
    app.route('/ntlm/connect', methods=['POST'])(test_password_handler)
    app.route('/ping', methods=['GET'])(ping_handler)

    app.run(threaded=True, host='0.0.0.0', port=int(listen_port))


if __name__ == '__main__':
    # Run tasks concurrently using multithreading
    t1 = Thread(target=api)
    t2 = Thread(target=sd_notify)
    t1.start()
    t2.start()
    t1.join()
    t2.join()
