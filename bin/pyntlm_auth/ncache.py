from flask import g
from samba import ntstatus

import utils

NT_KEY_USER_LOCKED = "*"
NT_KEY_USER_DISABLED = "-"
NT_KEY_USER_DOES_NOT_EXIST = "x"


def cache_v_template(domain, account, mac):
    return {
        "domain": domain,
        "account": account,
        "mac": mac,  # mac here will be the one that successfully logins
        "nt_key": '',
        "dirty": False,
        "bad_password_count": 0,
        "expires_at": utils.expires(3600),
        "last_login_attempt": utils.now(),
        "last_password_change": 0,
        "nt_status": 0,
        "update_time": utils.now()
    }


def cache_v_set(cache_v, dict):
    for key in dict:
        if key in cache_v:
            cache_v[key] = dict[key]
        if key == "nt_status":
            if dict[key] == ntstatus.NT_STATUS_NO_SUCH_USER:
                cache_v['nt_key'] = NT_KEY_USER_DOES_NOT_EXIST
            if dict[key] == ntstatus.NT_STATUS_ACCOUNT_LOCKED_OUT:
                cache_v['nt_key'] = NT_KEY_USER_LOCKED
            if dict[key] == ntstatus.NT_STATUS_ACCOUNT_DISABLED:
                cache_v['nt_key'] = NT_KEY_USER_DISABLED
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


def device_miss_root_miss():
    return


def device_miss_root_hit():
    return


def device_hit_root_miss():
    return


def device_hit_root_hit():
    return


def cached_login(domain, account_username, mac, challenge, nt_response):
    cache_key_root = build_cache_key(domain, account_username, '')
    cache_key_device = build_cache_key(domain, account_username, mac)

    cache_entry_device = get_cache_entry(cache_key_device)
    cache_entry_root = get_cache_entry(cache_key_root)

    nt_key = "",
    error_code = -1
    info = None

    if cache_entry_device is None and cache_entry_root is None:
        nt_key, error_code, info = device_miss_root_miss()
    if cache_entry_device is None and cache_entry_root is not None:
        nt_key, error_code, info = device_miss_root_hit()
    if cache_entry_device is not None and cache_entry_root is None:
        nt_key, error_code, info = device_hit_root_miss()
    if cache_entry_device is not None and cache_entry_root is not None:
        nt_key, error_code, info = device_hit_root_hit()

    return nt_key, error_code, info
