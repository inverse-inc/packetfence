import json
import os
import threading
import urllib.parse
import urllib.request

from flask import g, has_request_context

import log

CREDCACHE_URL = os.environ.get("CREDCACHE_URL", "").strip()
CREDCACHE_FORWARD_URL = os.environ.get("CREDCACHE_FORWARD_URL", "").strip()
SELF_CONNECTOR_ID = os.environ.get("SELF_CONNECTOR_ID", "").strip()
TIMEOUT_SECONDS = 2
NT_KEY_CACHE_PREFIX = "nt_key_cache:"


def _do_post(url, body, label):
    try:
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            log.debug(f"credcache {label} POST ok: status={resp.status} url={url}")
    except Exception as e:
        log.warning(f"credcache {label} POST failed for url={url}: {e}")


def _request_connector_id():
    if not has_request_context():
        return ""
    return (getattr(g, "request_connector_id", "") or "").strip()


def _build_body(key, value, expires_at):
    return json.dumps({
        "key": key,
        "value": value,
        "expires_at": expires_at,
    }).encode("utf-8")


def _push_primary(body, key):
    if not CREDCACHE_URL:
        return
    log.debug(f"credcache push_async: firing primary POST for key={key!r} to {CREDCACHE_URL}")
    threading.Thread(
        target=_do_post,
        args=(CREDCACHE_URL, body, "primary"),
        name="credcache-push",
        daemon=True,
    ).start()


def _maybe_push_forward(body, key):
    """Fire the secondary forward push at most once per request.

    Skipped when CREDCACHE_FORWARD_URL is unset, when no connector_id was
    carried on the request, when the request connector_id matches our own
    SELF_CONNECTOR_ID, or when an earlier call this request already fired
    it (via the g.credcache_forward_fired guard).
    """
    if not CREDCACHE_FORWARD_URL:
        return
    target = _request_connector_id()
    if not target or target == SELF_CONNECTOR_ID:
        return
    if has_request_context():
        if getattr(g, "credcache_forward_fired", False):
            return
        g.credcache_forward_fired = True
    forward = CREDCACHE_FORWARD_URL.rstrip("/") + "/" + urllib.parse.quote(target, safe="") + "/"
    log.debug(f"credcache: firing forward POST for key={key!r} to {forward}")
    threading.Thread(
        target=_do_post,
        args=(forward, body, "forward"),
        name="credcache-forward-push",
        daemon=True,
    ).start()


def push_async(key, value, expires_at):
    """Fire-and-forget POSTs mirroring an nt_key_cache:* chi_cache row.

    Primary push: CREDCACHE_URL — the connector-cache tied to this auth-api
    (typically the connector hosting the AD domain).

    Secondary push: CREDCACHE_FORWARD_URL/<request_connector_id>/ — the
    pfconnector-server credcache forwarder. Adds the same row to the cache
    of the connector whose pfconnector-remote received the original RADIUS
    request (read from g.request_connector_id, which ntlm_auth_handler sets
    from the JSON body that ntlm_auth_wrapper -c populated).

    The secondary push is skipped when:
      - request_connector_id is empty (request didn't go via pfconnector)
      - request_connector_id == SELF_CONNECTOR_ID (would push to ourselves;
        the primary push already covers this case)
      - CREDCACHE_FORWARD_URL is not configured
      - it has already fired once for this request

    API: POST .../api/v1/credcache/ {"key": "nt_key_cache:...",
                                      "value": "<json>",
                                      "expires_at": <int>}
    """
    if not key or not key.startswith(NT_KEY_CACHE_PREFIX):
        return
    body = _build_body(key, value, expires_at)
    _push_primary(body, key)
    _maybe_push_forward(body, key)


def push_forward_async(key, value, expires_at):
    """Forward-only secondary push.

    Used after a successful cached_login() hit, where the local
    chi_cache/connector-cache already has the row but the connector that
    received the original RADIUS request still needs to learn it. Without
    this, repeat MS-CHAP from the radius-receiving site keeps round-tripping
    to the AD-hosting site even though the nt_key is already cached locally.
    """
    if not key or not key.startswith(NT_KEY_CACHE_PREFIX):
        return
    body = _build_body(key, value, expires_at)
    _maybe_push_forward(body, key)


def fetch(cache_key):
    """Synchronous GET from CREDCACHE_URL/{domain}/{username}[/{mac}].

    API: GET /api/v1/credcache/{domain}/{username}[/{mac}] -> raw chi_cache
    `value` blob (JSON string with nt_key / nt_status fields). Returns the
    value string or None on miss, network error, or when CREDCACHE_URL is not
    set.
    """
    if not CREDCACHE_URL or not cache_key:
        return None
    # The credcache server stores keys without the "nt_key_cache:" prefix
    # and expects the remaining colon-delimited segments as URL path parts
    # (e.g. nt_key_cache:InverseINC:fdurand -> /InverseINC/fdurand).
    lookup_key = cache_key
    if lookup_key.startswith(NT_KEY_CACHE_PREFIX):
        lookup_key = lookup_key[len(NT_KEY_CACHE_PREFIX):]
    segments = [urllib.parse.quote(p, safe="") for p in lookup_key.split(":") if p]
    if not segments:
        return None
    url = CREDCACHE_URL.rstrip("/") + "/" + "/".join(segments)
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as resp:
            body = resp.read().decode("utf-8")
    except Exception as e:
        log.warning(f"credcache GET failed for {cache_key}: {e}")
        return None
    if body:
        log.info(f"credcache GET ok: nt_key retrieved for {cache_key}")
        log.debug(f"credcache GET body for {cache_key}: {body[:200]}")
        return body
    return None
