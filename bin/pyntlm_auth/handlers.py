from http import HTTPStatus
from flask import Flask, request, g
import ncache
import re
import hashlib
import binascii
import json
import utils
import ms_event
import global_vars
import rpc
import flags

from samba import param, NTSTATUSError, ntstatus

# For NTSTATUS, see:
# https://github.com/samba-team/samba/blob/master/libcli/util/ntstatus_err_table.txt
# or
# https://github.com/samba-team/samba/blob/master/examples/pcap2nbench/main.cpp

def format_response(nt_key_or_error_msg, error_code):
    if error_code == 0:
        return f'NT_KEY: {nt_key_or_error_msg}', HTTPStatus.OK

    if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
        return nt_key_or_error_msg, HTTPStatus.UNAUTHORIZED

    if error_code == ntstatus.NT_STATUS_NO_SUCH_USER:
        return nt_key_or_error_msg, HTTPStatus.NOT_FOUND

    if error_code == ntstatus.NT_STATUS_ACCOUNT_LOCKED_OUT or error_code == ntstatus.NT_STATUS_ACCOUNT_DISABLED:
        return nt_key_or_error_msg, HTTPStatus.LOCKED

    if error_code == flags.STATUS_DEVICE_BLOCKED:
        return nt_key_or_error_msg, HTTPStatus.UNAUTHORIZED

    return nt_key_or_error_msg, HTTPStatus.BAD_REQUEST


def ping_handler():
    return "pong", HTTPStatus.OK


def ntlm_connect_handler():
    with global_vars.s_lock:
        global_vars.s_reconnect_id = global_vars.s_connection_id

    global_vars.s_secure_channel_connection, global_vars.s_machine_cred, global_vars.s_connection_id, error_code, error_message = rpc.get_secure_channel_connection()

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

    global_vars.c_password = nt_hash

    with global_vars.s_lock:
        global_vars.s_reconnect_id = global_vars.s_connection_id

    global_vars.s_secure_channel_connection, global_vars.s_machine_cred, global_vars.s_connection_id, error_code, error_message = rpc.get_secure_channel_connection()

    if error_code == ntstatus.NT_STATUS_ACCESS_DENIED:
        return "Test machine account failed. Access Denied", HTTPStatus.UNAUTHORIZED
    if error_code != 0:
        return "Error while establishing secure channel connection: " + error_message, HTTPStatus.INTERNAL_SERVER_ERROR

    return "OK", HTTPStatus.OK


def ntlm_auth_handler():
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

        if 'domain' in data:
            domain = data['domain']
        else:
            domain = global_vars.c_domain

    except Exception as e:
        return f"Error processing JSON payload, {str(e)}", HTTPStatus.UNPROCESSABLE_ENTITY

    if isinstance(mac, str):
        mac = mac.strip()
    else:
        mac = ""

    if global_vars.c_nt_key_cache_enabled and hasattr(g, 'db') and mac != "":
        domain = global_vars.c_domain_identifier
        nt_key, error_code, info = ncache.cached_login(domain, account_username, mac, challenge, nt_response, )
    else:
        nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response, domain = domain)
    return format_response(nt_key, error_code)


def event_report_handler():
    try:
        required_keys = {'Domain', 'Events'}
        data = request.get_json()
        if data is None:
            return 'No JSON payload found in request', HTTPStatus.BAD_REQUEST
        for required_key in required_keys:
            if required_key not in data:
                return f'Invalid payload format, missing required key {required_key}', HTTPStatus.UNPROCESSABLE_ENTITY

        events = data['Events']
        for event in events:
            if not ms_event.check_event(event):
                return f"Event validation failed. Invalid event format.", HTTPStatus.UNPROCESSABLE_ENTITY

    except Exception as e:
        return f"Error processing JSON payload, {str(e)}", HTTPStatus.UNPROCESSABLE_ENTITY

    for event in data['Events']:
        ms_event.process_event(event)

    return "Event Accepted", HTTPStatus.ACCEPTED


def ntlm_expire_handler():
    try:
        required_keys = {'domain', 'account'}

        data = request.get_json()
        if data is None:
            return 'No JSON payload found in request', HTTPStatus.BAD_REQUEST
        for required_key in required_keys:
            if required_key not in data:
                return f'Invalid payload format, missing required key {required_key}', HTTPStatus.UNPROCESSABLE_ENTITY
        domain = data['domain']
        account = data['account']
        cache_key_root = ncache.build_cache_key(domain, account, '')

        ncache.delete_cache_entry(cache_key_root)
        ncache.delete_cache_entries(f"{cache_key_root}:%")

        return "OK", HTTPStatus.OK
    except Exception as e:
        return f"Error processing JSON payload, {str(e)}", HTTPStatus.UNPROCESSABLE_ENTITY

