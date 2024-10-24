import binascii
import hashlib
import re
import time
from http import HTTPStatus

import redis
from flask import request, g
from samba import ntstatus

import config_loader
import flags
import global_vars
import ms_event
import ncache
import redis_client
import rpc


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
    machine_accounts = config_loader.expand_machine_account_list()

    mapping, code, msg = _build_machine_account_bind_mapping(machine_accounts)
    if code != 0:
        return msg, code

    job_id, code, msg = _submit_machine_account_test_job(machine_accounts)
    if code != 0:
        return msg, code

    results = _poll_machine_account_test_job_results(job_id, machine_accounts)
    return _aggregate_results(results, machine_accounts)


def ntlm_connect_handler_with_password():
    data = request.get_json()

    if data is None:
        return "Invalid JSON payload: decoding failed\n", HTTPStatus.BAD_REQUEST

    if 'password' not in data:
        return "Invalid JSON payload: missing required field 'password'\n", HTTPStatus.UNPROCESSABLE_ENTITY

    nt_hash = ""
    password = data['password'].strip()
    if password:
        if re.search(r'^[a-fA-F0-9]{32}$', password):
            nt_hash = password
        else:
            nt4_digest = hashlib.new('md4', password.encode('utf-16le')).digest()
            nt_hash = binascii.hexlify(nt4_digest).decode('utf-8')

    machine_account = ""
    if ('machine_account' in data) and data["machine_account"].strip():
        machine_account = data["machine_account"].strip()
        if "$" not in machine_account:
            machine_account = f"{machine_account}$"

    machine_accounts = config_loader.expand_machine_account_list()
    if machine_account and (machine_account not in machine_accounts):
        msg = f"Machine account '{machine_account}' does not match current machine account name patterns"
        return msg, HTTPStatus.NOT_FOUND

    if machine_account:
        machine_accounts = [machine_account]

    mapping, code, msg = _build_machine_account_bind_mapping(machine_accounts)
    if code != 0:
        return msg, code

    job_id, code, msg = _submit_machine_account_test_job(machine_accounts, nt_hash)
    if code != 0:
        return msg, code

    results = _poll_machine_account_test_job_results(job_id, machine_accounts)
    return _aggregate_results(results, machine_accounts)


def _build_machine_account_bind_mapping(machine_accounts):
    mapping = {}

    for m in machine_accounts:
        key = f"{redis_client.namespace}:machine-account-bind:{m}"

        try:
            res = redis_client.r.get(name=key)
            if res is None:
                msg = f"error fetching machine account binding. machine account test failed: no binding for account {m}"
                code = HTTPStatus.INTERNAL_SERVER_ERROR
                return {}, code, msg
            else:
                mapping[m] = res

        except redis.ConnectionError:
            msg = "error fetching machine account binding. machine account test failed: redis connection error."
            code = HTTPStatus.INTERNAL_SERVER_ERROR
            return {}, code, msg

        except Exception as e:
            msg = f"error fetching machine account binding. machine account test failed: {str(e)}."
            code = HTTPStatus.INTERNAL_SERVER_ERROR
            return {}, code, msg

    return mapping, 0, ""


def _submit_machine_account_test_job(machine_accounts, password=""):
    job_id = time.time()

    key_lock = f"{redis_client.namespace}:async-test:lock:{job_id}"
    try:
        redis_client.r.lpush(key_lock, 1)
    except redis.ConnectionError:
        msg = "error submitting machine account test job: lock init failed due to redis connection error"
        code = HTTPStatus.INTERNAL_SERVER_ERROR
        return None, code, msg
    except Exception as e:
        msg = f"error submitting machine account test job: lock init failed due to {str(e)}"
        code = HTTPStatus.INTERNAL_SERVER_ERROR
        return None, code, msg

    for m in machine_accounts:
        key = f"{redis_client.namespace}:async-test:jobs:{m}"

        if password.strip() == "":
            value = job_id
        else:
            value = f"{job_id}:{password.strip()}"

        try:
            redis_client.r.lpush(key, value)

        except redis.ConnectionError:
            msg = "error fetching machine account binding. machine account test failed: redis connection error."
            code = HTTPStatus.INTERNAL_SERVER_ERROR
            return None, code, msg

        except Exception as e:
            msg = f"error fetching machine account binding. machine account test failed: {str(e)}."
            code = HTTPStatus.INTERNAL_SERVER_ERROR
            return None, code, msg

    return job_id, 0, ""


def _poll_machine_account_test_job_results(job_id, machine_accounts):
    exp_time = job_id + 2
    results = {}

    while time.time() < exp_time:
        time.sleep(0.3)

        for m in machine_accounts:
            if m in results and results[m]["status"] in ("OK", "Failed"):
                continue

            key = f"{redis_client.namespace}:async-test:results:{job_id}:{m}"

            try:
                res = redis_client.r.get(key)

                if res is None:
                    continue

                if res == "OK":
                    results[m] = {"status": "OK", "reason": None}
                    continue

                if isinstance(res, str) and res != "OK":
                    results[m] = {"status": "Failed", "reason": res}
                    continue

            except redis.ConnectionError:
                results[m] = {"status": "Exception", "reason": f"redis connection issue when fetching job result"}
            except Exception as e:
                results[m] = {"status": "Exception", "reason": f"redis error '{str(e)}' when fetching job result"}
    return results


def _aggregate_results(results, machine_accounts):
    timeout = []
    successful = []
    failed = []
    exception = []

    for m in machine_accounts:
        if m not in results:
            timeout.append(m)
            continue

        if results[m]["status"] == "OK":
            successful.append(m)
            continue

        if results[m]["status"] == "Failed":
            failed.append(m)
            continue

        if results[m]["status"] == "Exception":
            exception.append(m)
            continue

    if (not timeout) and (not failed) and (not exception):
        return "OK\n", HTTPStatus.OK

    s_successful = ""
    if successful:
        s_successful = "successful: " + ", ".join(successful) + "\n"

    s_timeout = ""
    if timeout:
        s_timeout = "timeout: " + ", ".join(timeout) + "\n"

    s_failed = ""
    if failed:
        s_failed = "Failed: \n" + \
                   "\n".join(f" {i}: {results[i]['status']}: {results[i]['reason']}" for i in failed) + \
                   "\n"

    s_exception = ""
    if exception:
        s_exception = "Exception occurred: \n" + \
                      "\n".join(f" {i}: {results[i]['status']}: {results[i]['reason']}" for i in exception) + \
                      "\n"

    msg = f"machine account test (partially) failed: \n{s_successful}{s_timeout}{s_failed}{s_exception}"
    return f"{msg}\n", HTTPStatus.UNPROCESSABLE_ENTITY


def ntlm_auth_handler():
    try:
        required_keys = {'username', 'mac', 'request-nt-key', 'challenge', 'nt-response'}
        optional_keys = {'domain'}

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
        nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response, domain=domain)
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
