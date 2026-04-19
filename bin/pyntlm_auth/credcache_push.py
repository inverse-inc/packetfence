import json
import os
import threading
import urllib.parse
import urllib.request

import log

CREDCACHE_URL = os.environ.get("CREDCACHE_URL", "").strip()
TIMEOUT_SECONDS = 2
NT_KEY_CACHE_PREFIX = "nt_key_cache:"


def _do_post(username, nt_key):
    try:
        body = json.dumps({
            "username": username,
            "key": nt_key,
        }).encode("utf-8")
        req = urllib.request.Request(
            CREDCACHE_URL,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            log.debug(f"credcache POST ok: status={resp.status} username={username}")
    except Exception as e:
        log.warning(f"credcache POST failed for username={username}: {e}")


def push_async(key, value, expires_at):
    """Fire-and-forget POST to CREDCACHE_URL.
    Pushes both root and per-device nt_key_cache:* keys (domain+username extracted from key).
    API: POST /api/v1/credcache/ {"username": "{domain}\\{user}", "key": "<nt_key_hex>"}"""
    log.debug(f"credcache push_async called: key={key!r} CREDCACHE_URL={CREDCACHE_URL!r}")
    if not CREDCACHE_URL:
        log.debug("credcache push_async: CREDCACHE_URL not set, skipping")
        return
    if not key or not key.startswith(NT_KEY_CACHE_PREFIX):
        log.debug(f"credcache push_async: key {key!r} does not start with {NT_KEY_CACHE_PREFIX!r}, skipping")
        return
    # key format: nt_key_cache:{domain}:{username} or nt_key_cache:{domain}:{username}:{mac}
    parts = key.split(":", 3)
    if len(parts) < 3:
        log.debug(f"credcache push_async: key {key!r} has unexpected format, skipping")
        return
    domain, account_username = parts[1], parts[2]
    try:
        nt_key = json.loads(value).get("nt_key", "")
    except Exception as e:
        log.debug(f"credcache push_async: failed to parse value JSON: {e}, skipping")
        return
    if not nt_key:
        log.debug(f"credcache push_async: nt_key empty for key={key!r}, skipping")
        return
    username = f"{domain}\\{account_username}"
    log.debug(f"credcache push_async: firing POST for username={username!r} to {CREDCACHE_URL}")
    threading.Thread(
        target=_do_post,
        args=(username, nt_key),
        name="credcache-push",
        daemon=True,
    ).start()


def fetch(domain, account_username):
    """Synchronous GET from CREDCACHE_URL/{domain}/{account_username}.

    API: GET /api/v1/credcache/{username} -> {"key": "<nt_key_hex>"}

    Returns the NT key string, or None on miss, network error, or when
    CREDCACHE_URL is not set.
    """
    if not CREDCACHE_URL or not domain or not account_username:
        return None
    username = f"{domain}\\{account_username}"
    safe_username = urllib.parse.quote(username, safe="")
    url = CREDCACHE_URL.rstrip("/") + f"/{safe_username}"
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        log.warning(f"credcache GET failed for {username}: {e}")
        return None

    if not isinstance(data, dict) or "key" not in data:
        log.warning(f"credcache GET returned unexpected payload for {username}")
        return None

    return data["key"] or None
