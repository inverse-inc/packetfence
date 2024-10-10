from flask import g
from samba import ntstatus
import rpc
import json
import global_vars
import flags

import utils
import datetime

NT_KEY_USER_LOCKED = "*"
NT_KEY_USER_DISABLED = "-"
NT_KEY_USER_DOES_NOT_EXIST = "x"

YES = 1
NO = 0
UNKNOWN = -1


def is_ndl(code):
    ndl_list = [
        ntstatus.NT_STATUS_NO_SUCH_USER,
        ntstatus.NT_STATUS_ACCOUNT_LOCKED_OUT,
        ntstatus.NT_STATUS_ACCOUNT_DISABLED
    ]
    if code in ndl_list:
        return True
    return False


def determine_cache_expire_time(nt_time_last_password_changed):
    lpc = utils.nt_time_to_datetime(nt_time_last_password_changed)
    l = lpc + global_vars.c_ad_old_password_allowed_period
    d = utils.expires(global_vars.c_nt_key_cache_expire)

    if global_vars.c_ad_old_password_allowed_period == 0:
        return d

    if lpc == 0 or lpc == 2147483647:   # indicates that user never changed their password
        return d

    if l < utils.now():
        return d

    if utils.now() < l < d:
        return l
    else:
        return d


def is_still_accept_old_password(nt_time_last_password_changed):
    lpc = utils.nt_time_to_datetime(nt_time_last_password_changed)
    if lpc == 0 or lpc == 2147483647:    # indicates that user never changed their password
        return False
    if global_vars.c_ad_old_password_allowed_period > 0:
        if lpc + global_vars.c_ad_old_password_allowed_period * 60 > utils.now():
            return True

    return False


def is_hitting_bad_password_threshold(c_device, c_root):
    if global_vars.c_ad_account_lockout_threshold > 0:
        if c_root['last_login_attempt'] + global_vars.c_ad_reset_account_lockout_counter_after * 60 >= utils.now():
            if c_device['bad_password_count'] >= global_vars.c_max_allowed_password_attempts_per_device:
                return True
            if c_root['bad_password_count'] >= global_vars.c_ad_account_lockout_threshold - 1:
                return True
    return False


def reset_bad_password_count(c_root):
    if c_root['last_login_attempt'] + global_vars.c_ad_reset_account_lockout_counter_after * 60 < utils.now():
        c_root['bad_password_count'] = 0
    return c_root


def reset_bad_password_count_for_device(c_root, c_device):
    if c_device['last_login_attempt'] + global_vars.c_ad_reset_account_lockout_counter_after * 60 < utils.now():
        c_device['bad_password_count'] = 0

    if c_root['last_successful_logon'] > c_device['update_time']:
        c_device['bad_password_count'] = 0
    return c_device


def cache_v_template(domain, account, mac):
    return {
        "nt_key": '',
        "nt_status": 0,
        "dirty": UNKNOWN,                        # if cache is dirty. 0 - no, 1 - yes, -1 - unknown / can not determine.

        "create_time": utils.now(),         # cache entry creation time.
        "update_time": utils.now(),         # last update time on our side
        "nt_key_cache_time": 0,             # first successful login time, and got this NT key.
        "last_login_attempt": utils.now(),  # last time that performs a transitive login.
        "bad_password_count": 0,            # AD or our side
        "last_password_change": 0,          # AD or windows events
        "last_successful_logon": 0,         # AD or our side
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


def trigger_security_event(mac, domain, account):
    security_event_blocker_key = f"security_event:{domain}:{account}:{mac}"
    if get_cache_entry(security_event_blocker_key) is not None:
        return
    else:
        update_cache_entry(security_event_blocker_key, '', utils.expires(1800))

    entries = None
    query = "SELECT `mac`, `pid` FROM `node` WHERE `mac` = %s LIMIT 1;"
    if hasattr(g, 'db'):
        g.db.execute(query, mac)
        entries = g.db.fetchone()

    if entries is None:
        query = "INSERT INTO `node` " \
                "(`mac`, `pid`, `detect_date`, `status`, `voip`) VALUES " \
                "(%s, 'default', %s, 'unreg', 'no')"
        if hasattr(g, 'db'):
            now = utils.to_ymd_hms(utils.now())
            g.db.execute(query, (mac, now))

    query = "INSERT INTO `security_event` " \
            "(`id`, `mac`, `security_event_id`, `start_date`, `release_date`, `status`, `ticket_ref`, `notes`)VALUES " \
            "(NULL, %s, 3000008, %s, %s, %s, %s, %s)"
    if hasattr(g, 'db'):
        start_date = datetime.datetime.fromtimestamp(utils.now()).strftime("%Y-%m-%d %H:%M:%S")
        release_date = datetime.datetime.fromtimestamp(utils.expires(1800)).strftime("%Y-%m-%d %H:%M:%S")
        status = 'open'
        ticket_ref = ''

        detail = {
            "domain": domain,
            "user": account,
        }
        notes = json.dumps(detail)

        g.db.execute(query, (mac, start_date, release_date, status, ticket_ref, notes))
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
    cache_key_root = build_cache_key(domain, account_username)
    cache_key_device = build_cache_key(domain, account_username, mac)

    cache_v = cache_v_template(domain, account_username, mac)
    nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response)

    if is_ndl(error_code):
        cache_v = cache_v_set(cache_v, {'nt_status': error_code})
        cache_v_json = json.dumps(cache_v)
        update_cache_entry(cache_key_root, cache_v_json, 60)

    if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
        cache_v = cache_v_set(cache_v, {
            'nt_status': ntstatus.NT_STATUS_WRONG_PASSWORD,
            'bad_password_count': 1,
        })
        cache_v_json = json.dumps(cache_v)
        update_cache_entry(cache_key_device, cache_v_json, utils.expires(global_vars.c_nt_key_cache_expire))
        update_cache_entry(cache_key_root, cache_v_json, utils.expires(global_vars.c_nt_key_cache_expire))

    if error_code == 0:
        dirty = UNKNOWN if is_still_accept_old_password(info.base.last_password_change) else NO

        cache_v = cache_v_set(cache_v, {
            "nt_key": nt_key,
            "dirty": dirty,
            "nt_key_cache_time": utils.now(),
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.now(),
        })

        cache_v_json = json.dumps(cache_v)
        exp = determine_cache_expire_time(info.base.last_password_change)
        update_cache_entry(cache_key_device, cache_v_json, exp)
        update_cache_entry(cache_key_root, cache_v_json, exp)

    return nt_key, error_code, info


def device_miss_root_hit(domain, account_username, mac, challenge, nt_response, c_root):
    cache_key_root = build_cache_key(domain, account_username)
    cache_key_device = build_cache_key(domain, account_username, mac)

    try:
        cache_v_root = json.loads(c_root['value'])
        cache_v_device = cache_v_template(domain, account_username, mac)
    except Exception as e:
        print(f"  Exception caught while handling cached authentication, error was: {e}")
        return '', -1, None

    if is_ndl(cache_v_root['nt_status']):
        return '', cache_v_root['nt_status'], None

    cache_v_root = reset_bad_password_count(cache_v_root)

    if is_hitting_bad_password_threshold(cache_v_device, cache_v_root):
        trigger_security_event(mac, domain, account_username)
        return '', flags.STATUS_DEVICE_BLOCKED, None

    nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response)

    if is_ndl(error_code):
        cache_v_root = cache_v_set(cache_v_root, {"nt_status": error_code})
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_root, cache_v_json_root, 60)

    if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
        cache_v_device = cache_v_set(cache_v_device, {
            'nt_status': ntstatus.NT_STATUS_WRONG_PASSWORD,
            'bad_password_count': 1,
        })
        cache_v_root = cache_v_set(cache_v_root, {
            "bad_password_count": cache_v_root["bad_password_count"] + 1,
            "last_login_attempt": utils.now(),
            "update_time": utils.now()
        })
        cache_v_json_device = json.dumps(cache_v_device)
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_device, cache_v_json_device, utils.expires(global_vars.c_nt_key_cache_expire))
        update_cache_entry(cache_key_root, cache_v_json_root, utils.expires(global_vars.c_nt_key_cache_expire))

    if error_code == 0:
        dirty = UNKNOWN if is_still_accept_old_password(info.base.last_password_change) else NO

        cache_v_device = cache_v_set(cache_v_device, {
            "nt_key": nt_key,
            "dirty": dirty,
            "nt_key_cache_time": utils.now(),
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.now(),
        })

        exp = determine_cache_expire_time(info.base.last_password_change)

        cache_v_root = cache_v_set(cache_v_root, {
            "nt_status": 0,
            "update_time": utils.now(),
            "last_login_attempt": utils.now(),
            "bad_password_count": 0,
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.now(),
        })
        cache_v_json_device = json.dumps(cache_v_device)
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_device, cache_v_json_device, exp)
        update_cache_entry(cache_key_root, cache_v_json_root, exp)

    return nt_key, error_code, info


def device_hit_root_hit(domain, account_username, mac, challenge, nt_response, c_device=None, c_root=None):
    cache_key_root = build_cache_key(domain, account_username)
    cache_key_device = build_cache_key(domain, account_username, mac)

    try:
        cache_v_root = json.loads(c_root['value'])
        cache_v_device = json.loads(c_device['value'])
    except Exception as e:
        print(f"  Exception caught while handling cached authentication, error was: {e}")
        return '', -1, None

    if is_ndl(cache_v_root['nt_status']):
        return '', cache_v_root['nt_status'], None

    cache_v_root = reset_bad_password_count(cache_v_root)
    cache_v_device = reset_bad_password_count_for_device(cache_v_root, cache_v_device)

    if cache_v_device['nt_key'] != "":
        if cache_v_device['dirty'] == NO:
            return cache_v_device['nt_key'], cache_v_device['nt_status'], None
        else:
            if is_hitting_bad_password_threshold(cache_v_device, cache_v_root):
                trigger_security_event(mac, domain, account_username)
                return cache_v_device['nt_key'], cache_v_device['nt_status'], None
    else:
        if is_hitting_bad_password_threshold(cache_v_device, cache_v_root):
            trigger_security_event(mac, domain, account_username)
            return cache_v_device['nt_key'], cache_v_device['nt_status'], None

    nt_key, error_code, info = rpc.transitive_login(account_username, challenge, nt_response)

    if is_ndl(error_code):
        cache_v_device = cache_v_set(cache_v_device, {"nt_status": error_code})
        cache_v_root = cache_v_set(cache_v_root, {"nt_status": error_code})
        cache_v_json_device = json.dumps(cache_v_device)
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_device, cache_v_json_device, 1)
        update_cache_entry(cache_key_root, cache_v_json_root, 60)

    if error_code == ntstatus.NT_STATUS_WRONG_PASSWORD:
        cache_v_device = cache_v_set(cache_v_device, {
            "update_time": utils.now(),
            "bad_password_count": cache_v_device["bad_password_count"] + 1,
            "last_login_attempt": utils.now(),
        })
        cache_v_root = cache_v_set(cache_v_root, {
            "update_time": utils.now(),
            "bad_password_count": cache_v_root["bad_password_count"] + 1,
            "last_login_attempt": utils.now()
        })
        cache_v_json_device = json.dumps(cache_v_device)
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_device, cache_v_json_device, utils.expires(global_vars.c_nt_key_cache_expire))
        update_cache_entry(cache_key_root, cache_v_json_root, utils.expires(global_vars.c_nt_key_cache_expire))

    if error_code == 0:
        dirty = UNKNOWN if is_still_accept_old_password(info.base.last_password_change) else NO

        cache_v_set(cache_v_device, {
            "nt_key": nt_key,
            "dirty": dirty,
            "nt_status": 0,
            "last_login_attempt": utils.now(),
            "update_time": utils.now(),
            "bad_password_count": 0,
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.now(),
        })

        cache_v_set(cache_v_root, {
            "nt_key": nt_key,
            "dirty": dirty,
            "nt_status": 0,
            "last_login_attempt": utils.now(),
            "update_time": utils.now(),
            "bad_password_count": 0,
            "last_password_change": utils.nt_time_to_datetime(info.base.last_password_change),
            "last_successful_logon": utils.now(),
        })
        exp = determine_cache_expire_time(info.base.last_password_change)

        cache_v_json_device = json.dumps(cache_v_device)
        cache_v_json_root = json.dumps(cache_v_root)
        update_cache_entry(cache_key_device, cache_v_json_device, exp)
        update_cache_entry(cache_key_root, cache_v_json_root, exp)

    return nt_key, error_code, info


def device_hit_root_miss(domain, account_username, mac, challenge, nt_response, c_device):
    return device_hit_root_hit(domain, account_username, mac, challenge, nt_response, c_device=c_device, c_root=c_device)
