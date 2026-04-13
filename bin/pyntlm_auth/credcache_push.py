import json
import os
import threading
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
    """Fire-and-forget mirror of a chi_cache write. Only mirrors nt_key_cache:*
    keys. No-op unless CREDCACHE_URL is set in the environment (i.e. only the
    -remote variant running next to pfconnector-remote)."""
    if not CREDCACHE_URL:
        return
    if not key or not key.startswith(NT_KEY_CACHE_PREFIX):
        return
    threading.Thread(
        target=_do_post,
        args=(key, value, expires_at),
        name="credcache-push",
        daemon=True,
    ).start()


def fetch(domain, username):
    """Synchronous GET to pfconnector-remote's credcache for (domain, username).

    Returns a dict shaped like a row from ncache.get_cache_entries() --
    {'key': <chi_cache key>, 'value': <json string>, 'expires_at': <int>} --
    so callers can feed it into the existing dispatch logic.

    Returns None on miss, network error, or when CREDCACHE_URL is not set.
    """
    if not CREDCACHE_URL or not domain or not username:
        return None
    url = CREDCACHE_URL.rstrip("/") + f"/{domain}/{username}"
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        log.warning(f"credcache GET failed for {domain}/{username}: {e}")
        return None

    if not isinstance(data, dict) or "value" not in data:
        log.warning(f"credcache GET returned unexpected payload for {domain}/{username}")
        return None

    return {
        "key": f"{NT_KEY_CACHE_PREFIX}{domain}:{username}",
        "value": data["value"],
        "expires_at": data.get("expires_at", 0),
    }
