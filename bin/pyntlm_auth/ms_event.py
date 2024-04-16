import json

import ncache
import utils

EVENT_TYPE_USER_CREATED = 4720
EVENT_TYPE_USER_ENABLED = 4722
EVENT_TYPE_PASSWORD_CHANGE = 4723
EVENT_TYPE_PASSWORD_RESET = 4724
EVENT_TYPE_USER_DISABLED = 4725
EVENT_TYPE_USER_LOCKED_OUT = 4740
EVENT_TYPE_USER_UNLOCKED = 4767


def check_event(event):
    if "EventTypeID" not in event:
        return False

    known_event_ids = [EVENT_TYPE_USER_CREATED, EVENT_TYPE_USER_ENABLED, EVENT_TYPE_PASSWORD_CHANGE,
                       EVENT_TYPE_PASSWORD_RESET, EVENT_TYPE_USER_DISABLED,
                       EVENT_TYPE_USER_LOCKED_OUT, EVENT_TYPE_USER_UNLOCKED]
    if event["EventTypeID"] not in known_event_ids:
        return False

    return True


def process_event(event):
    if event['EventTypeID'] == EVENT_TYPE_PASSWORD_RESET:
        process_event_password_reset(event)
    if event['EventTypeID'] == EVENT_TYPE_PASSWORD_CHANGE:
        process_event_password_change(event)
    return True


def process_event_password_reset(event):
    record_id = event['RecordID']
    event_time = utils.extract_event_timestamp(event['EventTime'])
    domain = event['TargetDomainName']
    account = event['TargetUserName']
    event['EventTime'] = event_time

    print(f"  ---- handling event password reset : happens on {utils.to_ymd_hms(event_time)} ({event_time}) for ID {record_id}: {account}@{domain} ")

    key_root = ncache.build_cache_key(domain, account)
    cache_entry_root = ncache.get_cache_entry(key_root)
    cache_entry_devices = ncache.search_cache_entries(f"{key_root}:%")

    if cache_entry_root is not None:
        cache_v = json.loads(cache_entry_root['value'])

        if event_time > cache_v['update_time']:
            cache_v['dirty'] = ncache.YES
            cache_v['update_time'] = utils.now()
            cache_v['dirty_time'] = utils.now()
            cache_v_json = json.dumps(cache_v)
            ncache.update_cache_entry(key_root, cache_v_json, cache_entry_root['expires_at'])

    if cache_entry_devices is not None:
        for cache_entry_device in cache_entry_devices:
            cache_v = json.loads(cache_entry_device['value'])
            if event_time > cache_v['update_time']:
                cache_v['dirty'] = ncache.YES
                cache_v['update_time'] = utils.now()
                cache_v['dirty_time'] = utils.now()
                cache_v_json = json.dumps(cache_v)
                ncache.update_cache_entry(cache_entry_device['key'], cache_v_json, cache_entry_device['expires_at'])

    return True


def process_event_password_change(event):
    record_id = event['RecordID']
    event_time = utils.extract_event_timestamp(event['EventTime'])
    domain = event['TargetDomainName']
    account = event['TargetUserName']
    event['EventTime'] = event_time

    print(f"  ---- handling event password change: happens on {utils.to_ymd_hms(event_time)} ({event_time}) for ID {record_id}: {account}@{domain} ")

    key_root = ncache.build_cache_key(domain, account)
    cache_entry_root = ncache.get_cache_entry(key_root)
    cache_entry_devices = ncache.search_cache_entries(f"{key_root}:%")

    if cache_entry_root is not None:
        cache_v = json.loads(cache_entry_root['value'])

        if event_time > cache_v['update_time']:
            cache_v['dirty'] = ncache.YES
            cache_v['update_time'] = utils.now()
            cache_v['dirty_time'] = utils.now()
            cache_v_json = json.dumps(cache_v)
            ncache.update_cache_entry(key_root, cache_v_json, cache_entry_root['expires_at'])

    if cache_entry_devices is not None:
        for cache_entry_device in cache_entry_devices:
            cache_v = json.loads(cache_entry_device['value'])
            if event_time > cache_v['update_time']:
                cache_v['dirty'] = ncache.YES
                cache_v['update_time'] = utils.now()
                cache_v['dirty_time'] = utils.now()
                cache_v_json = json.dumps(cache_v)
                ncache.update_cache_entry(cache_entry_device['key'], cache_v_json, cache_entry_device['expires_at'])

    return True
