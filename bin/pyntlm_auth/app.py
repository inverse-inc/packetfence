import binascii
import configparser
import datetime
import os
import socket
import sys
import threading
from configparser import ConfigParser
from http import HTTPStatus

from flask import Flask, request
from samba import param, NTSTATUSError, ntstatus
from samba.credentials import Credentials, DONT_USE_KERBEROS
from samba.dcerpc import netlogon
from samba.dcerpc.misc import SEC_CHAN_WKSTA
from samba.dcerpc.netlogon import (netr_Authenticator)

machine_cred = None
secure_channel_connection = None
connection_id = 1
reconnect_id = 0
connection_last_active_time = datetime.datetime.now()
lock = threading.Lock()

conf_path = "/usr/local/pf/conf/domain.conf"
listen_port = os.getenv("LISTEN")
identifier = os.getenv("IDENTIFIER")
rewrite_resolv_conf_flag = os.getenv("REWRITE_RESOLV_CONF")

config = ConfigParser()
try:
    with open(conf_path, 'r') as file:
        config.read_file(file)

    if identifier in config:
        ad_server = config.get(identifier, 'ad_server')
        netbios_name = config.get(identifier, 'server_name').upper()
        realm = config.get(identifier, 'dns_name')
        server_string = config.get(identifier, 'server_name')
        workgroup = config.get(identifier, 'workgroup')
        workstation = config.get(identifier, 'server_name').upper()
        username = config.get(identifier, 'server_name').upper() + "$"
        password = config.get(identifier, 'machine_account_password')
        password_is_nt_hash = config.get(identifier, 'password_is_nt_hash')
        domain = config.get(identifier, 'workgroup').lower()
        dns_servers = config.get(identifier, 'dns_servers')
    else:
        print("The specified section does not exist in the config file.")
        sys.exit(1)
except FileNotFoundError as e:
    print("The specified config file does not exist.")
    sys.exit(1)
except configparser.Error as e:
    print(f"Error reading config file: {e}")
    sys.exit(1)

try:
    server_name, alias_list, ip_list = socket.gethostbyaddr(ad_server)
except Exception as e:
    print("Unable to retrieve AD FQDN of AD domain")
    sys.exit(1)


def generate_resolv_conf(dns_name, dns_servers_string):
    with open('/etc/resolv.conf', 'w') as file:
        file.write(f"search {dns_name}\n")
        file.write("\n")
        file.write("options timeout:1\n")
        file.write("options attempts:1\n")
        file.write("\n")

        dns_servers = dns_servers_string.split(",")
        for dns_server in dns_servers:
            file.write(f"nameserver {dns_server}\n")
        file.write("\n")


if (rewrite_resolv_conf_flag is not None) and (rewrite_resolv_conf_flag.upper() == "YES"):
    generate_resolv_conf(realm, dns_servers)


def init_secure_connection():
    global machine_cred
    global secure_channel_connection
    lp = param.LoadParm()

    try:
        lp.load("/root/default.conf")
    except KeyError:
        raise KeyError("SMB_CONF_PATH not set")

    lp.set('netbios name', netbios_name)
    lp.set('realm', realm)
    lp.set('server string', server_string)
    lp.set('workgroup', workgroup)
    lp.set('ldap connection timeout', "2")
    lp.set('winbind request timeout', '2')

    machine_cred = Credentials()

    machine_cred.guess(lp)
    machine_cred.set_secure_channel_type(SEC_CHAN_WKSTA)
    machine_cred.set_kerberos_state(DONT_USE_KERBEROS)

    machine_cred.set_workstation(workstation)
    machine_cred.set_username(username)
    machine_cred.set_password(password)

    machine_cred.set_password_will_be_nt_hash(True if password_is_nt_hash == "1" else False)
    machine_cred.set_domain(domain)

    error_code = 0
    error_message = ""
    try:
        secure_channel_connection = netlogon.netlogon("ncacn_np:%s[schannel,seal]" % server_name, lp, machine_cred)
    except NTSTATUSError as e:
        error_code = e.args[0]
        error_message = e.args[1]
        print(f"---- error in init secure connection: NT_Error, error_code={error_code}, error_message={error_message}")

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
        print(f"---- error in init secure connection: General, error_code={error_code}, error_message={error_message}")
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
    if error_code != 0:
        return "Error while establishing secure channel connections: " + error_message, HTTPStatus.INTERNAL_SERVER_ERROR

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
            return 'Invalid JSON payload format, missing required keys', HTTPStatus.BAD_REQUEST

        account_username = data['username']
        challenge = data['challenge']
        nt_response = data['nt-response']

    except Exception as e:
        print(e)
        return "Error processing JSON payload", HTTPStatus.INTERNAL_SERVER_ERROR

    secure_channel_connection, machine_cred, connection_id, error_code, error_message = get_secure_channel_connection()
    if error_code != 0:
        return "Error while establishing secure channel connections: " + error_message, HTTPStatus.INTERNAL_SERVER_ERROR

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
            print("---- NT KEY: ", nt_key_str)
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

            print("---- NT Error encountered while authenticating user: ", e)
            reconnect_id = connection_id
            return f"NT Error: {e}", HTTPStatus.INTERNAL_SERVER_ERROR
        except Exception as e:
            reconnect_id = connection_id
            print("-----------General error:", e)
            return "Error handling request", HTTPStatus.INTERNAL_SERVER_ERROR


app = Flask(__name__)
app.route('/ntlm/auth', methods=['POST'])(ntlm_auth_handler)
app.route('/ntlm/connect', methods=['GET'])(ntlm_connect_handler)
# if name == __main__:
app.run(threaded=True, host='0.0.0.0', port=int(listen_port))
# app.run(debug='debug', processes=1, threaded=True, host='0.0.0.0', port=int(listen_port))
