import time

import global_vars
from samba import param, NTSTATUSError, ntstatus
from samba.credentials import Credentials, DONT_USE_KERBEROS
from samba.dcerpc.misc import SEC_CHAN_WKSTA
from samba.dcerpc import netlogon, nbt
import utils
import log
import datetime
from samba.dcerpc.netlogon import (netr_Authenticator, MSV1_0_ALLOW_WORKSTATION_TRUST_ACCOUNT, MSV1_0_ALLOW_MSVCHAPV2)
import binascii
from samba.net import Net


def find_dc(lp):
    error_code = -1
    error_message = "unknown error"

    if global_vars.c_dns_servers.strip() != "":
        log.debug(f"find_dc using dns servers: {global_vars.c_dns_servers}")
        try:
            net = Net(Credentials(), lp)
            dc = net.finddc(domain=lp.get('realm'), flags=nbt.NBT_SERVER_LDAP | nbt.NBT_SERVER_DS)
            return 0, "", dc.pdc_dns_name
        except NTSTATUSError as e:
            error_code = e.args[0]
            error_message = e.args[1]
        except Exception as e:
            try:
                error_code = e.args[0]
            except Exception:
                pass
            error_message = str(e)

    if global_vars.c_server_name.strip() != "" and global_vars.c_ad_server.strip() != "":
        log.debug(f"find_dc using AD FQDN: {global_vars.c_server_name} (ad_server: {global_vars.c_ad_server})")
        try:
            net = Net(Credentials(), lp)
            dc = net.finddc(address=global_vars.c_server_name, flags=nbt.NBT_SERVER_LDAP | nbt.NBT_SERVER_DS)
            return 0, "", dc.pdc_dns_name
        except NTSTATUSError as e:
            error_code = e.args[0]
            error_message = e.args[1]
        except Exception as e:
            try:
                error_code = e.args[0]
            except Exception:
                pass
            error_message = str(e)

    return error_code, error_message, None


def init_secure_connection():
    netbios_name = global_vars.c_netbios_name
    realm = global_vars.c_realm
    server_string = global_vars.c_server_string
    workgroup = global_vars.c_workgroup
    workstation = global_vars.c_workstation
    password = global_vars.c_password
    domain = global_vars.c_domain
    username = global_vars.c_username

    lp = param.LoadParm()
    lp.load_default()

    lp.set('netbios name', netbios_name)
    lp.set('realm', realm)
    lp.set('server string', server_string)
    lp.set('workgroup', workgroup)

    log.debug(f"lp: netbios = {netbios_name}, realm = {realm}, server_str = {server_string}, workgroup = {workgroup}")

    find_dc_start = time.time()
    error_code, error_message, pdc_dns_name = find_dc(lp)
    time_elapsed = time.time() - find_dc_start
    log.debug(f"find dc: pdc_dns_name = {pdc_dns_name}, e = {error_code}, m = {error_message}")

    if time_elapsed > 5:
        log.warning(f"find_dc tooks {time_elapsed} sec. There might be one or more unreachable domain controllers")

    if error_code != 0:
        return global_vars.s_secure_channel_connection, global_vars.s_machine_cred, error_code, error_message
    else:
        global_vars.c_server_name = pdc_dns_name

    server_name = global_vars.c_server_name  # FQDN of Domain Controller

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

    context = f"ncacn_np:{server_name}[schannel,seal]"
    log.debug(f"establish secure channel, context = {context}")

    try:
        global_vars.s_secure_channel_connection = netlogon.netlogon(context, lp, global_vars.s_machine_cred)
        log.debug(f"secure connection established successfully.")
    except NTSTATUSError as e:
        error_code = e.args[0]
        error_message = e.args[1]

        log.error(f"NT Error {hex(error_code)}: {error_message}, when establishing secure connection.")

        if error_code == 0xc0000001:
            log.error("Did you give the wrong 'workstation' parameter in domain configuration ?")
        if error_code == 0xc0000022:
            log.error("Are you using a wrong password for a machine account?")
            log.error("If you are in a cluster, did you re-used the machine account and reset with another password?")
        if error_code == 0xc0000122:
            log.error(f"This is usually due to a incorrect AD FQDN. The current AD FQDN you are using is: {server_name}")

        log.debug("Parameter used in establish secure channel are:")
        log.debug(f"lp.netbios_name: {netbios_name}")
        log.debug(f"lp.realm: {realm}")
        log.debug(f"lp.server_string: {server_string}")
        log.debug(f"lp.workgroup: {workgroup}")
        log.debug(f"workstation: {workstation}")
        log.debug(f"username: {username}")
        log.debug(f"password: {utils.mask_password(password)}")
        log.debug(f"set_NT_hash_flag: True")
        log.debug(f"domain: {domain}")
        log.debug(f"server_name(ad_fqdn): {server_name}")
    except Exception as e:
        error_code = e.args[0]
        error_message = e.args[1]
        log.warning(f"error occurred when establishing secure connection: e = {error_code}, m = {error_message}.")

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


def transitive_login(account_username, challenge, nt_response, domain=None):
    if domain is None:
        domain = global_vars.c_domain

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
        logon.identity_info.workstation.string = global_vars.c_workstation
        logon.identity_info.parameter_control = MSV1_0_ALLOW_WORKSTATION_TRUST_ACCOUNT | MSV1_0_ALLOW_MSVCHAPV2

        try:
            result = global_vars.s_secure_channel_connection.netr_LogonSamLogonWithFlags(global_vars.c_server_name,
                                                                                         global_vars.c_workstation,
                                                                                         current, subsequent,
                                                                                         logon_level, logon,
                                                                                         validation_level,
                                                                                         netr_flags)
            (return_auth, info, foo, bar) = result

            nt_key = [x if isinstance(x, str) else hex(x)[2:].zfill(2) for x in info.base.key.key]
            nt_key_str = ''.join(nt_key)
            log.info(f"Auth OK '{account_username}@{domain}', NT_KEY = '{utils.mask_password(nt_key_str)}' using {global_vars.c_server_name}\\{global_vars.c_username}")
            return nt_key_str.encode('utf-8').strip().decode('utf-8'), 0, info
        except NTSTATUSError as e:
            nt_error_code = e.args[0]
            nt_error_message = f"NT Error: code: {nt_error_code}, message: {str(e)}"
            log.warning(f"auth failed: user = '{account_username}@{domain}', e = {nt_error_code}, m = {nt_error_message} using {global_vars.c_server_name}\\{global_vars.c_username}")

            if nt_error_code == 0xc0000022:
                log.warning("Is this machine account is shared by another ntlm_auth process (or another cluster node)?")
            if nt_error_code == 0xC000006a:
                log.warning("Are you using the correct password or there's a password change recently?")

            global_vars.s_reconnect_id = global_vars.s_connection_id
            return nt_error_message, nt_error_code, None
        except Exception as e:
            global_vars.s_reconnect_id = global_vars.s_connection_id
            if isinstance(e.args, tuple) and len(e.args) > 0:
                log.warning(f"auth failed: user = '{account_username}@{domain}', e = {e.args[0]} m = {str(e)} using {global_vars.c_server_name}\\{global_vars.c_username}")
                return f"General Error: code {e.args[0]}, {str(e)}", e.args[0], None
            else:
                log.warning(f"auth failed: user = '{account_username}@{domain}', m = {str(e)} using {global_vars.c_server_name}\\{global_vars.c_username}")
                return f"General Error: {str(e)}", -1, None
