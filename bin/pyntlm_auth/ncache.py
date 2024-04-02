from flask import g
from samba import ntstatus
import rpc
import json
import global_vars

import utils

NT_KEY_USER_LOCKED = "*"
NT_KEY_USER_DISABLED = "-"
NT_KEY_USER_DOES_NOT_EXIST = "x"


def is_ndl(code):
    ndl_list = [
        ntstatus.NT_STATUS_NO_SUCH_USER,
        ntstatus.NT_STATUS_ACCOUNT_LOCKED_OUT,
        ntstatus.NT_STATUS_ACCOUNT_DISABLED
    ]
    if code in ndl_list:
        return True
    return False


def determine_cache_expire_time(last_password_changed):
    lpc = utils.nt_time_to_datetime(last_password_changed)
    l = lpc + global_vars.c_ad_old_password_allowed_period
    d = utils.expires(global_vars.c_nt_key_cache_expire)

    if lpc == 0 or lpc == 2147483647:
        return d

    if l < utils.now():
        return utils.now()

    if utils.now() < l < d:
        return l
    else:
        return d


def is_hitting_bad_password_threshold(c_device, c_root):
    if global_vars.c_ad_account_lockout_threshold > 0:
        if c_root['last_login_attempt'] + global_vars.c_ad_reset_account_lockout_counter_after * 60 >= utils.now():
            if c_device['bad_password_count'] >= global_vars.c_max_allowed_password_attempts_per_device:
                return True
            if c_root['bad_password_count'] >= global_vars.c_ad_account_lockout_threshold - 1:
                return True
    return False


def is_still_locked_out(c_device):
    if global_vars.c_ad_account_lockout_duration == 0:    # indicates that the account will not be auto unlocked.
        return True
    if global_vars.c_ad_account_lockout_duration > 0:
        if c_device['nt_status'] == ntstatus.NT_STATUS_ACCOUNT_LOCKED_OUT:
            if c_device['lockout_time'] + global_vars.c_ad_account_lockout_duration * 60 >= utils.now():
                return True
    return False


def cache_v_template(domain, account, mac):
    return {
        "nt_key": '',
        "dirty": False,

        "last_login_attempt": utils.now(),  # last time that performs a transitive login.
        "nt_status": 0,
        "update_time": utils.now(),         # last update time on our side
        "bad_password_count": 0,            # AD or our side
        "last_password_change": 0,          # AD or windows events
        "last_successful_logon": 0,         # AD or our side
        "last_failed_logon": 0,             # AD or our side
        "lockout_time" : 0,                 # lock out time from our side or AD

        "expires_at": utils.expires(global_vars.c_nt_key_cache_expire),
    }


def cache_v_set(cache_v, dict):
    for key in dict:
        if key in cache_v:
            cache_v[key] = dict[key]
    return cache_v


def build_cache_key(domain, account_username, mac=''):
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
        g.db.execute(query, (key, value, expires_at, value))


def get_cache_entry(key):
    query = "SELECT `key`, `value`, `expires_at` FROM `chi_cache` WHERE `key` = %s LIMIT 1"
    if hasattr(g, 'db'):
        g.db.execute(query, key)
        return g.db.fetchone()
    else:
        return None


def get_cache_entries(key1, key2):
    query = "SELECT `key`, `value`, `expires_at` FROM `chi_cache` WHERE `key` IN (%s, %s)"
    if hasattr(g, 'db'):
        g.db.execute(query, (key1, key2))
        return g.db.fetchall()
    else:
        return None


def search_cache_entries(key):
    query = "SELECT `key`, `value`, `expires_at` FROM `chi_cache` WHERE `key` LIKE %s "
    if hasattr(g, 'db'):
        g.db.execute(query, key)
        return g.db.fetchall()
    else:
        return None


def delete_cache_entry(key):
    query = "DELETE FROM `chi_cache` WHERE `key` = %s "
    if hasattr(g, 'db'):
        g.db.execute(query, key)


def delete_cache_entries(key_pattern):
    query = "DELETE FROM `chi_cache` WHERE `key` LIKE %s "
    if hasattr(g, 'db'):
        g.db.execute(query, key_pattern)


def trigger_security_event():
    return


def cached_login(domain, account_username, mac, challenge, nt_response):
    cache_entry_root = None
    cache_entry_device = None
    cache_key_root = build_cache_key(domain, account_username, '')
    cache_key_device = build_cache_key(domain, account_username, mac)

    cache_entries = get_cache_entries(cache_key_root, cache_key_device)
    for cache_entry in cache_entries:
        if cache_entry['key'] == cache_key_root:
            cache_entry_root = cache_entry
        if cache_entry['key'] == cache_key_device:
            cache_entry_device = cache_entry

    nt_key = "",
    error_code = -1
    info = None

    if cache_entry_device is None and cache_entry_root is None:
        nt_key, error_code, info = device_miss_root_miss(domain, account_username, mac, challenge, nt_response)

    if cache_entry_device is None and cache_entry_root is not None:
        nt_key, error_code, info = device_miss_root_hit(domain, account_username, mac, challenge, nt_response,
                                                        c_root=cache_entry_root)

    if cache_entry_device is not None and cache_entry_root is None:
        nt_key, error_code, info = device_hit_root_miss(domain, account_username, mac, challenge, nt_response,
                                                        c_device=cache_entry_device)

    if cache_entry_device is not None and cache_entry_root is not None:
        nt_key, error_code, info = device_hit_root_hit(domain, account_username, mac, challenge, nt_response,
                                                       c_device=cache_entry_device, c_root=cache_entry_root)

    return nt_key, error_code, info


def device_miss_root_miss(domain, account_username, mac, challenge, nt_response):
    print("  cache status: device [ ], root [ ]")
    cache_key_root = build_cache_key(domain, account_username)
    cache_key_device = build_cache_key(domain, account_username, mac)

    cache_v = cache_v_template(domain, account_username, mac)
    nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response)

    if error_code == 0:
        cache_v = cache_v_set(cache_v, {
            "nt_key": nt_key,
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
            "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon)})
        cache_v_json = json.dumps(cache_v)
        exp = determine_cache_expire_time(info.base.last_password_change)
        update_cache_entry(cache_key_device, cache_v_json, exp)
        update_cache_entry(cache_key_root, cache_v_json, exp)

    if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
        cache_v = cache_v_set(cache_v, {'nt_status': ntstatus.NT_STATUS_WRONG_PASSWORD, 'bad_password_count': 1})
        cache_v_json = json.dumps(cache_v)
        update_cache_entry(cache_key_device, cache_v_json, utils.expires(global_vars.c_nt_key_cache_expire))
        update_cache_entry(cache_key_root, cache_v_json, utils.expires(global_vars.c_nt_key_cache_expire))

    if is_ndl(error_code):
        cache_v = cache_v_set(cache_v, {'nt_status': error_code})
        cache_v_json = json.dumps(cache_v)
        update_cache_entry(cache_key_device, cache_v_json, utils.expires(60))
    return nt_key, error_code, info


def device_miss_root_hit(domain, account_username, mac, challenge, nt_response, c_root):
    print("  cache status: device [ ], root [*]")
    cache_key_root = build_cache_key(domain, account_username)
    cache_key_device = build_cache_key(domain, account_username, mac)
    cache_v = cache_v_template(domain, account_username, mac)

    try:
        cache_v_root = json.loads(c_root['value'])
    except Exception as e:
        print(f"  Exception caught while handling cached authentication, error was: {e}")
        return '', -1, None

    if global_vars.c_ad_account_lockout_threshold > 0 and cache_v_root['bad_password_count'] >= global_vars.c_ad_account_lockout_threshold - 1:
        trigger_security_event()
        return '', global_vars.n_device_blocked, None

    nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response)

    if error_code == 0:
        cache_v = cache_v_set(cache_v, {
            "nt_key": nt_key,
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
            "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon)})
        cache_v_json = json.dumps(cache_v)
        exp = determine_cache_expire_time(info.base.last_password_change)
        update_cache_entry(cache_key_device, cache_v_json, exp)

        if cache_v_root['nt_status'] == 0 and cache_v_root['dirty'] and cache_v_root['nt_key'] != nt_key:
            cache_v_root = cache_v_set(cache_v_root, {"nt_key": nt_key})
            exp = utils.expires(global_vars.c_nt_key_cache_expire)
        if cache_v_root['nt_status'] != 0:
            cache_v_root = cache_v_set(cache_v_root, {"nt_key": nt_key})

        cache_v_root = cache_v_set(cache_v_root, {
            "last_login_attempt": utils.now(),
            "nt_status": 0,
            "update_time": utils.now(),
            "bad_password_count": 0,
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
            "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon)
        })
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_root, cache_v_json_root, exp)

    if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
        cache_v = cache_v_set(cache_v, {'nt_status': ntstatus.NT_STATUS_WRONG_PASSWORD, 'bad_password_count': 1})
        cache_v_json = json.dumps(cache_v)
        update_cache_entry(cache_key_device, cache_v_json, utils.expires(global_vars.c_nt_key_cache_expire))
        cache_v_root = cache_v_set(cache_v_root, {
            "bad_password_count": cache_v_root["bad_password_count"] +1,
            "last_login_attempt": utils.now(),
            "update_time": utils.now()
        })
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_root, cache_v_json_root, utils.expires(global_vars.c_nt_key_cache_expire))

    if is_ndl(error_code):
        cache_v = cache_v_set(cache_v, {'nt_status': error_code})
        cache_v_json = json.dumps(cache_v)
        update_cache_entry(cache_key_device, cache_v_json, utils.expires(60))

    return nt_key, error_code, info


def device_hit_root_hit(domain, account_username, mac, challenge, nt_response, c_device = None, c_root = None):
    print("  cache status: device [*], root [*]")
    cache_key_root = build_cache_key(domain, account_username)
    cache_key_device = build_cache_key(domain, account_username, mac)

    try:
        cache_v_root = json.loads(c_root['value'])
        cache_v_device = json.loads(c_device['value'])
    except Exception as e:
        print(f"  Exception caught while handling cached authentication, error was: {e}")
        return '', -1, None

    if not cache_v_device['dirty']:
        if cache_v_device['nt_status'] == 0:
            return cache_v_device['nt_key'], 0, None

        if is_ndl(cache_v_device['nt_status']):
            return cache_v_device['nt_key'], cache_v_device['nt_status'], None

        if cache_v_device['nt_status'] == ntstatus.NT_STATUS_WRONG_PASSWORD:
            if is_hitting_bad_password_threshold(cache_v_device, cache_v_root):
                trigger_security_event()
                return cache_v_device['nt_key'], cache_v_device['nt_status'], None

            nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response)

            if error_code == 0:
                cache_v_device = cache_v_set(cache_v_device, {
                    "nt_key": nt_key,
                    "nt_status": 0,
                    "bad_password_count": 0,
                    "update_time": utils.now(),
                    "last_login_attempt": utils.now(),
                    "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
                    "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
                    "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon),
                })
                cache_v_json = json.dumps(cache_v_device)
                update_cache_entry(cache_key_device, cache_v_json, utils.expires(global_vars.c_nt_key_cache_expire))
                cache_v_root = cache_v_set(cache_v_root, {
                    "nt_key": nt_key,
                    "nt_status": 0,
                    "bad_password_count": 0,
                    "update_time": utils.now(),
                    "last_login_attempt": utils.now(),
                    "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
                    "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
                    "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon),
                    "dirty": False
                })
                cache_v_json_root = json.dumps(cache_v_root)
                update_cache_entry(cache_key_root, cache_v_json_root, utils.expires(global_vars.c_nt_key_cache_expire))

            if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
                cache_v_device = cache_v_set(cache_v_device, {
                    "bad_password_count": cache_v_device["bad_password_count"] + 1,
                    "update_time": utils.now(),
                    "last_login_attempt": utils.now(),
                })
                cache_v_root = cache_v_set(cache_v_root, {
                    "bad_password_count": cache_v_root["bad_password_count"] + 1,
                    "update_time": utils.now(),
                    "last_login_attempt": utils.now()
                })
                cache_v_json_device = json.dumps(cache_v_device)
                cache_v_json_root = json.dumps(cache_v_root)

                update_cache_entry(cache_key_device, cache_v_json_device, utils.expires(global_vars.c_nt_key_cache_expire))
                update_cache_entry(cache_key_root, cache_v_json_root, utils.expires(global_vars.c_nt_key_cache_expire))

            if is_ndl(error_code):
                cache_v_device = cache_v_set(cache_v_device,{
                    "nt_status": error_code,
                    "bad_password_count": 0,
                    "last_login_attempt": utils.now()
                })
                cache_v_json_device = json.dumps(cache_v_device)
                update_cache_entry(cache_key_device, cache_v_json_device, utils.expires(60))

            return nt_key, error_code, info
        return '', -1, None

    else:
        if is_hitting_bad_password_threshold(cache_v_device, cache_v_root):
            return cache_v_device['nt_key'], cache_v_device['nt_status'], None

        nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response)

        if error_code == 0:
            if nt_key == cache_v_device['nt_key']:    # dirty = 1 && got same NT key => old password graceful time
                exp = determine_cache_expire_time(cache_v_device['last_password_change'])
                cache_v_device = cache_v_set(cache_v_device, {
                    "bad_password_count": 0,
                    "update_time": utils.now(),
                    "last_login_attempt": utils.now(),
                    "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
                    "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
                    "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon),
                })
                cache_v_json_device = json.dumps(cache_v_device)
                update_cache_entry(cache_key_device, cache_v_json_device, utils.expires(exp))

                if cache_v_root["dirty"]:
                    cache_v_root = cache_v_set(cache_v_root, {
                        "bad_password_count": 0,
                        "update_time": utils.now(),
                        "last_login_attempt": utils.now(),
                        "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
                        "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
                        "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon),
                    })
                    if cache_v_root['nt_status'] != 0:
                        cache_v_root = cache_v_set(cache_v_root, {"nt_key": nt_key, "nt_status":0})
                    cache_v_json_root = json.dumps(cache_v_root)
                    update_cache_entry(cache_key_root, cache_v_json_root, utils.expires(exp))
                else:
                    cache_v_root = cache_v_set(cache_v_root, {
                        "bad_password_count": 0,
                        "update_time": utils.now(),
                        "last_login_attempt": utils.now(),
                        "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
                        "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
                        "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon),
                    })
                    cache_v_json_root = json.dumps(cache_v_root)
                    update_cache_entry(cache_key_root, cache_v_json_root, c_root['expires'])
            else:
                cache_v_device = cache_v_set(cache_v_device, {
                    "nt_key": nt_key,
                    "dirty": False,
                    "bad_password_count": 0,
                    "update_time": utils.now(),
                    "last_login_attempt": utils.now(),
                    "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
                    "last_successful_logon": utils.nt_time_to_datetime(info.base.last_successful_logon),
                    "last_failed_logon": utils.nt_time_to_datetime(info.base.last_failed_logon),
                })
                cache_v_json_device = json.dumps(cache_v_device)
                update_cache_entry(cache_key_device, cache_v_json_device, utils.expires(global_vars.c_nt_key_cache_expire))
                update_cache_entry(cache_key_root, cache_v_json_device, utils.expires(global_vars.c_nt_key_cache_expire))

        if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
            cache_v_device = cache_v_set(cache_v_device, {
                "bad_password_count": cache_v_device["bad_password_count"] +1,
                "update_time": utils.now(),
                "last_login_attempt": utils.now(),
            })
            cache_v_root = cache_v_set(cache_v_root, {
                "bad_password_count": cache_v_root["bad_password_count"] + 1,
                "update_time": utils.now(),
                "last_login_attempt": utils.now()
            })
            cache_v_json_device = json.dumps(cache_v_device)
            cache_v_json_root = json.dumps(cache_v_root)

            update_cache_entry(cache_key_device, cache_v_json_device, utils.expires(global_vars.c_nt_key_cache_expire))
            update_cache_entry(cache_key_root, cache_v_json_root, utils.expires(global_vars.c_nt_key_cache_expire))

        if is_ndl(error_code):
            cache_v_device = cache_v_set(cache_v_device,{
                "nt_status": error_code,
                "bad_password_count": 0,
                "last_login_attempt": utils.now()
            })
            cache_v_json = json.dumps(cache_v_device)
            update_cache_entry(cache_key_device, cache_v_json, utils.expires(60))

        return nt_key, error_code, info


def device_hit_root_miss(domain, account_username, mac, challenge, nt_response, c_device):
    print("  cache status: device [*], root [ ]")
    return device_hit_root_hit(domain, account_username, mac, challenge, nt_response, c_device=c_device, c_root=c_device)
