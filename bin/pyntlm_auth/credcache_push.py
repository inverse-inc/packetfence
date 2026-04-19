import json
import os
import threading
import urllib.parse
import urllib.request

import log

CREDCACHE_URL = os.environ.get("CREDCACHE_URL", "").strip()
TIMEOUT_SECONDS = 2
NT_KEY_CACHE_PREFIX = "nt_key_cache:"


def _do_post(key, value, expires_at):
    try:
        body = json.dumps({
            "key": key,
            "value": value,
            "expires_at": expires_at,
        }).encode("utf-8")
        req = urllib.request.Request(
            CREDCACHE_URL,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            log.debug(f"credcache POST ok: status={resp.status} key={key}")
    except Exception as e:
        log.warning(f"credcache POST failed for key={key}: {e}")


def push_async(key, value, expires_at):
    """Fire-and-forget POST to CREDCACHE_URL.
    Mirrors a chi_cache row (key, value, expires_at) for nt_key_cache:* keys.
    API: POST /api/v1/credcache/ {"key": "nt_key_cache:...", "value": "<json>", "expires_at": <int>}"""
    if not CREDCACHE_URL:
        return
    if not key or not key.startswith(NT_KEY_CACHE_PREFIX):
        return
    log.debug(f"credcache push_async: firing POST for key={key!r} to {CREDCACHE_URL}")
    threading.Thread(
        target=_do_post,
        args=(key, value, expires_at),
        name="credcache-push",
        daemon=True,
    ).start()


def fetch(cache_key):
    """Synchronous GET from CREDCACHE_URL/{urlencoded cache_key}.

    API: GET /api/v1/credcache/{key} -> raw chi_cache `value` blob (JSON string
    with nt_key / nt_status fields). Returns the value string or None on miss,
    network error, or when CREDCACHE_URL is not set.
    """
    if not CREDCACHE_URL or not cache_key:
        return None
    safe_key = urllib.parse.quote(cache_key, safe="")
    url = CREDCACHE_URL.rstrip("/") + f"/{safe_key}"
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as resp:
            body = resp.read().decode("utf-8")
    except Exception as e:
        log.warning(f"credcache GET failed for {cache_key}: {e}")
        return None
    return body or None
