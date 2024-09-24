import global_vars
import config_generator
from samba import param, NTSTATUSError, ntstatus
from samba.credentials import Credentials, DONT_USE_KERBEROS
from samba.dcerpc.misc import SEC_CHAN_WKSTA
from samba.dcerpc import netlogon
import utils
import datetime
from samba.dcerpc.netlogon import (netr_Authenticator, MSV1_0_ALLOW_WORKSTATION_TRUST_ACCOUNT, MSV1_0_ALLOW_MSVCHAPV2)
import binascii


def init_secure_connection():
    netbios_name = global_vars.c_netbios_name
    realm = global_vars.c_realm
    server_string = global_vars.c_server_string
    workgroup = global_vars.c_workgroup
    workstation = global_vars.c_workstation
    password = global_vars.c_password
    domain = global_vars.c_domain
    username = global_vars.c_username
    server_name = global_vars.c_server_name

    lp = param.LoadParm()
    try:
        config_generator.generate_empty_conf()
        lp.load("/usr/local/pf/var/conf/default.conf")
    except KeyError:
        raise KeyError("SMB_CONF_PATH not set")

    lp.set('netbios name', netbios_name)
    lp.set('realm', realm)
    lp.set('server string', server_string)
    lp.set('workgroup', workgroup)

    global_vars.s_machine_cred = Credentials()

    global_vars.s_machine_cred.guess(lp)
    global_vars.s_machine_cred.set_secure_channel_type(SEC_CHAN_WKSTA)
    global_vars.s_machine_cred.set_kerberos_state(DONT_USE_KERBEROS)

    global_vars.s_machine_cred.set_workstation(workstation)
    global_vars.s_machine_cred.set_username(username)
    global_vars.s_machine_cred.set_password(password)

    global_vars.s_machine_cred.set_password_will_be_nt_hash(True)
    global_vars.s_machine_cred.set_domain(domain)

    error_code = 0
    error_message = ""
    try:
        global_vars.s_secure_channel_connection = netlogon.netlogon(f"ncacn_np:{server_name}[schannel,seal]", lp,
                                                                    global_vars.s_machine_cred)
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
        print(f"  server_name(ad_fqdn): {server_name}")
    except Exception as e:
        error_code = e.args[0]
        error_message = e.args[1]
        print(f"Error in init secure connection: General, error_code={error_code}, error_message={error_message}.")
    return global_vars.s_secure_channel_connection, global_vars.s_machine_cred, error_code, error_message


def get_secure_channel_connection():
    with global_vars.s_lock:
        if global_vars.s_secure_channel_connection is None or global_vars.s_machine_cred is None or (
                global_vars.s_reconnect_id != 0 and global_vars.s_connection_id <= global_vars.s_reconnect_id) or (
                datetime.datetime.now() - global_vars.s_connection_last_active_time).total_seconds() > 5 * 60:
            global_vars.s_secure_channel_connection, global_vars.s_machine_cred, error_code, error_message = init_secure_connection()
            global_vars.s_connection_id += 1
            global_vars.s_reconnect_id = global_vars.s_connection_id if error_code != 0 else 0
            global_vars.s_connection_last_active_time = datetime.datetime.now()
            return global_vars.s_secure_channel_connection, global_vars.s_machine_cred, global_vars.s_connection_id, error_code, error_message
        else:
            global_vars.s_connection_last_active_time = datetime.datetime.now()
            return global_vars.s_secure_channel_connection, global_vars.s_machine_cred, global_vars.s_connection_id, 0, ""


def transitive_login(account_username, challenge, nt_response, domain = None):
    server_name = global_vars.c_server_name
    if domain is None:
        domain = global_vars.c_domain
    workstation = global_vars.c_workstation
    global_vars.s_secure_channel_connection, global_vars.s_machine_cred, global_vars.s_connection_id, error_code, error_message = get_secure_channel_connection()
    if error_code != 0:
        return f"Error while establishing secure channel connection: {error_message}", error_code, None

    with global_vars.s_lock:
        try:
            auth = global_vars.s_machine_cred.new_client_authenticator()
        except Exception as e:
            # usually we won't reach this if machine cred is authenticated successfully. Just in case.
            global_vars.s_reconnect_id = global_vars.s_connection_id
            return f"Error in creating authenticator: {str(e)}", e.args[0], None

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
            result = global_vars.s_secure_channel_connection.netr_LogonSamLogonWithFlags(server_name, workstation,
                                                                                         current, subsequent,
                                                                                         logon_level, logon,
                                                                                         validation_level,
                                                                                         netr_flags)
            (return_auth, info, foo, bar) = result

            nt_key = [x if isinstance(x, str) else hex(x)[2:].zfill(2) for x in info.base.key.key]
            nt_key_str = ''.join(nt_key)
            print(f"  Successfully authenticated '{account_username}', NT_KEY is: '{utils.mask_password(nt_key_str)}'.")
            return nt_key_str.encode('utf-8').strip().decode('utf-8'), 0, info
        except NTSTATUSError as e:
            nt_error_code = e.args[0]
            nt_error_message = f"NT Error: code: {nt_error_code}, message: {str(e)}"
            print(f"  Failed while authenticating user: '{account_username}' with NT Error: {e}.")
            global_vars.s_reconnect_id = global_vars.s_connection_id
            return nt_error_message, nt_error_code, None
        except Exception as e:
            global_vars.s_reconnect_id = global_vars.s_connection_id
            print(f"  Failed while authenticating user: '{account_username}' with General Error: {e}.")
            if isinstance(e.args, tuple) and len(e.args) > 0:
                return f"General Error: code {e.args[0]}, {str(e)}", e.args[0], None
            else:
                return f"General Error: {str(e)}", -1, None
