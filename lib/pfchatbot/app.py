"""
Minimal PacketFence chatbot (on-prem).

Provider-agnostic (OpenAI, Anthropic) FastAPI app. At startup it builds a
fastembed-backed RAG index over the current PacketFence version's OpenAPI
operations plus any local files / URLs configured in the environment. It
exposes four tools to the model — pf_search_operations, pf_describe_operation,
pf_call_operation, pf_search_docs — and loops until the model has an answer.

The customer supplies PROVIDER and API_KEY externally (e.g. from the
PacketFence admin UI); this service is stateless and BYOK for generation.

Env:
    PROVIDER=openai|anthropic          MODEL=<optional; provider default>
    API_KEY=<customer key>
    PF_BASE_URL=https://localhost:9999/api/v1
    PF_USERNAME=admin                  PF_PASSWORD=secret
    PF_VERIFY_TLS=false
    PF_OPENAPI_URL=<url> | PF_OPENAPI_FILE=<path>
    RAG_LOCAL_FILES=path1,path2,...    RAG_URLS=url1,url2,...
    RAG_EMBED_MODEL=BAAI/bge-small-en-v1.5

Run:
    pip install -r requirements.txt
    uvicorn app:app --host 0.0.0.0 --port 8800
"""
from __future__ import annotations

import contextvars
import hashlib
import json
import os
import re
import subprocess
import threading
import time
import uuid
from urllib.parse import quote, urlsplit, urlencode

import numpy as np

import httpx
from fastapi import FastAPI, Request, UploadFile, File, Form
from fastapi.responses import JSONResponse, Response
from fastapi.staticfiles import StaticFiles

import providers
from prompts import SYSTEM, version_line, style_addendum, read_only_line
from tools import TOOLS, label
from rag import Embedder, Index, Document, load_openapi_operations, load_local_files, load_urls

# load a local .env file if present (no extra dependency)
try:
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")) as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _k, _v = _line.split("=", 1)
                _v = _v.strip()
                # strip a trailing inline comment (" # ...") unless the value is
                # quoted — otherwise `RAG_EMBED_BATCH=8   # note` becomes the
                # whole string and int() blows up at startup
                if _v[:1] in ("'", '"'):
                    _q2 = _v[0]
                    _end = _v.find(_q2, 1)
                    _v = _v[1:_end] if _end > 0 else _v[1:]
                else:
                    _hash = _v.find(" #")
                    if _hash >= 0:
                        _v = _v[:_hash]
                    elif _v.startswith("#"):
                        _v = ""
                os.environ.setdefault(_k.strip(), _v.strip())
except FileNotFoundError:
    pass

# ── config (env) ─────────────────────────────────────────────────────────────
PROVIDER      = os.environ.get("PROVIDER", "").strip().lower()
API_KEY       = os.environ.get("API_KEY", "")
MODEL         = os.environ.get("MODEL", "") or None
PF_BASE_URL   = os.environ.get("PF_BASE_URL", "https://localhost:9999/api/v1").rstrip("/")
PF_USERNAME   = os.environ.get("PF_USERNAME", "")
PF_PASSWORD   = os.environ.get("PF_PASSWORD", "")


def _derive_admin_url(base_url: str) -> str:
    """Derive the admin web UI base URL from the REST API URL."""
    try:
        p = urlsplit(base_url)
        return f"{p.scheme}://{p.hostname}"
    except Exception:
        return ""


PF_ADMIN_URL  = os.environ.get("PF_ADMIN_URL", "").rstrip("/") or _derive_admin_url(PF_BASE_URL)

# ── PacketFence version ──────────────────────────────────────────────────────
PF_RELEASE_FILE = os.environ.get("PF_RELEASE_FILE", "/pf-release")
_VER_RE = re.compile(r"(\d+\.\d+(?:\.\d+)?)")


def _detect_pf_version() -> str:
    """The running PacketFence version, tried in order of trustworthiness:
    an explicit override, the release file the service mounts, then the version
    the OpenAPI spec declares. Returns "" rather than guessing."""
    env = (os.environ.get("PF_VERSION") or "").strip()
    if env:
        return env
    try:
        with open(PF_RELEASE_FILE, "r", encoding="utf-8", errors="replace") as f:
            m = _VER_RE.search(f.read())
            if m:
                return m.group(1)
    except OSError:
        pass
    v = (_state.get("spec_version") or "").strip()
    m = _VER_RE.search(v) if v else None
    return m.group(1) if m else ""


PF_OPENAPI    = os.environ.get("PF_OPENAPI_URL", "")
PF_OPENAPI_F  = os.environ.get("PF_OPENAPI_FILE", "openapi.json")
VERIFY_TLS    = os.environ.get("PF_VERIFY_TLS", "false").lower() == "true"
RAG_FILES     = [p for p in os.environ.get("RAG_LOCAL_FILES", "").split(",") if p.strip()]
# If no explicit files/dirs are configured, index everything in the docs dir.
if not RAG_FILES:
    RAG_FILES = [os.environ.get("RAG_DOCS_DIR", "/docs")]
RAG_URLS      = [u for u in os.environ.get("RAG_URLS", "").split(",") if u.strip()]
RAG_EMBED     = os.environ.get("RAG_EMBED_MODEL", "").strip() or None
RAG_RERANK    = os.environ.get("RAG_RERANK_MODEL", "").strip() or None
TESTTOOL_SOCK = os.environ.get("PF_TESTTOOL_SOCK", "/run/pf-testtool/helper.sock")
WRITE_METHODS = {"post", "put", "patch", "delete"}

# ── PacketFence client ───────────────────────────────────────────────────────
# A flat 30s read timeout is fine for PacketFence's local API but far too short
# for a large self-hosted/NIM model doing a multi-tool turn, which is where
# "Could not reach ...: The read operation timed out" came from. Connect stays
# short so an unreachable host still fails fast.
LLM_TIMEOUT = float(os.environ.get("LLM_TIMEOUT", "180"))
LLM_RETRIES = int(os.environ.get("LLM_RETRIES", "4"))


class _RetryTransport(httpx.HTTPTransport):
    """Wait out rate limits instead of surfacing them to the user.

    A 429 means the request was never processed, so retrying is always safe, and
    the provider tells us how long to wait (Retry-After header, or 'try again in
    9.33s' in the body). Without this, one busy agent turn exhausts the
    per-minute token budget and the next message fails outright.

    5xx is retried for GET only: a POST/PATCH that returned 500 may already have
    been applied, and re-sending it could double-apply a PacketFence write."""

    _WAIT_RE = re.compile(r"try again in ([0-9.]+)\s*(ms|s)\b", re.I)

    def __init__(self, *a, attempts: int = 4, **kw):
        super().__init__(*a, **kw)
        self._attempts = max(1, attempts)

    def _wait_for(self, resp, attempt: int) -> float:
        ra = resp.headers.get("retry-after")
        if ra:
            try:
                return min(float(ra), 60.0)
            except ValueError:
                pass
        try:
            m = self._WAIT_RE.search(resp.read().decode("utf-8", "replace"))
            if m:
                v = float(m.group(1))
                return min(v / 1000.0 if m.group(2).lower() == "ms" else v, 60.0)
        except Exception:
            pass
        return min(2.0 ** attempt, 30.0)

    def handle_request(self, request):
        resp = None
        for attempt in range(self._attempts):
            resp = super().handle_request(request)
            retryable = resp.status_code == 429 or (
                resp.status_code in (500, 502, 503, 504)
                and request.method.upper() == "GET")
            if not retryable or attempt == self._attempts - 1:
                return resp
            wait = self._wait_for(resp, attempt)
            print(f"[pf-bot] {resp.status_code} from {request.url.host}; retrying in "
                  f"{wait:.1f}s ({attempt + 1}/{self._attempts - 1})", flush=True)
            resp.close()
            time.sleep(wait + 0.25)
        return resp


http = httpx.Client(
    verify=VERIFY_TLS,
    timeout=httpx.Timeout(connect=10.0, read=LLM_TIMEOUT, write=30.0, pool=10.0),
    transport=_RetryTransport(verify=VERIFY_TLS, attempts=LLM_RETRIES),
)

# ── debug instrumentation: when a collector is active (verbose trace),
#    record every outbound HTTP request on the shared client — this covers
#    both LLM API calls (OpenAI/Anthropic) and PacketFence API calls. ──
_dbg_events: contextvars.ContextVar = contextvars.ContextVar("dbg_events", default=None)


def _dbg_on_request(request):
    if _dbg_events.get() is not None:
        request.extensions["dbg_t0"] = time.time()


def _dbg_on_response(response):
    ev = _dbg_events.get()
    if ev is None:
        return
    t0 = response.request.extensions.get("dbg_t0")
    dt = f"{time.time() - t0:.2f}s" if t0 else "?"
    u = response.request.url
    size = response.headers.get("content-length", "?")
    ev.append(
        (
            time.time(),
            f"\u00b7 http {response.request.method} {u.host}{u.path} "
            f"\u2192 {response.status_code}, {size}B in {dt}",
        )
    )


http.event_hooks["request"].append(_dbg_on_request)
http.event_hooks["response"].append(_dbg_on_response)
_state: dict = {"token": None, "ops": {}, "rag": None, "embedder": None}
# Pending write operations awaiting user confirmation (token -> op details).
# Kept in-memory only; a restart clears them (safe — nothing has executed yet).
_pending_writes: dict = {}
_PENDING_TTL = 600  # seconds a confirmation stays valid


def login():
    r = http.post(PF_BASE_URL + "/login", json={"username": PF_USERNAME, "password": PF_PASSWORD})
    r.raise_for_status()
    _state["token"] = r.json().get("token")
    return _state["token"]


def auth():
    if not _state["token"] and PF_USERNAME:
        login()
    return {"Authorization": _state["token"]} if _state["token"] else {}


def _parse_spec(body: str, hint: str = "") -> dict:
    """Parse a raw spec body as JSON first, YAML as fallback."""
    try:
        return json.loads(body)
    except ValueError:
        pass
    try:
        import yaml  # PyYAML
        return yaml.safe_load(body) or {}
    except Exception as e:
        raise RuntimeError(f"could not parse spec {hint!r}: not JSON or YAML ({e})")


def load_spec():
    if PF_OPENAPI:
        r = http.get(PF_OPENAPI, headers=auth())
        r.raise_for_status()
        spec = _parse_spec(r.text, hint=PF_OPENAPI)
    else:
        with open(PF_OPENAPI_F) as f:
            spec = _parse_spec(f.read(), hint=PF_OPENAPI_F)
    info = spec.get("info") if isinstance(spec, dict) else None
    if isinstance(info, dict) and info.get("version"):
        _state["spec_version"] = str(info["version"])
    ops: dict = {}
    for path, methods in (spec.get("paths") or {}).items():
        for method, op in methods.items():
            m = method.lower()
            if m not in {"get", "head", "post", "put", "patch", "delete"}:
                continue
            oid = op.get("operationId") or f"{m}_" + path.strip("/").replace("/", "_").replace("{", "").replace("}", "")
            ops[oid] = {"id": oid, "method": m, "path": path, "summary": op.get("summary", ""),
                        "description": op.get("description", ""), "tags": op.get("tags", []),
                        "parameters": op.get("parameters", []), "requestBody": op.get("requestBody", {}),
                        "is_write": m in WRITE_METHODS}
    _state["ops"] = ops
    return len(ops)


RAG_CACHE_DIR = os.environ.get("RAG_CACHE_DIR", os.path.expanduser("~/.cache/pf-chatbot"))


def _rag_signature() -> str:
    """Fingerprint of the corpus inputs: embed model, file stats, URL list, op ids.
    If none of these changed since last run, cached embeddings are reused.
    Note: URL *content* changes are not detected — delete the cache dir to force
    a refetch of RAG_URLS."""
    from rag.corpus import CORPUS_VERSION
    h = hashlib.sha256()
    h.update(("v" + CORPUS_VERSION + "|" + (RAG_EMBED or "default-model")).encode())
    # Expand any directory entries to their doc files so the fingerprint reflects
    # the actual indexed content (a dir's own stat doesn't change when a file
    # inside it does). Mirrors the extension filter in load_local_files.
    # Fingerprint all doc files, INCLUDING asciidoc fragments (.adoc): a guide's
    # master .asciidoc pulls in fragments via include::, so a fragment edit must
    # still change the signature even though the master's mtime doesn't.
    _exts = (".txt", ".md", ".pdf", ".html", ".htm", ".rst", ".asciidoc", ".adoc")
    sig_paths: list[str] = []
    for p in RAG_FILES:
        p = p.strip()
        if os.path.isdir(p):
            for root, _dirs, files in os.walk(p):
                for fn in sorted(files):
                    if fn.lower().endswith(_exts) and not fn.startswith("."):
                        sig_paths.append(os.path.join(root, fn))
        elif p:
            sig_paths.append(p)
    for p in sorted(sig_paths):
        try:
            st = os.stat(p)
            h.update(f"|{p}|{st.st_size}|{int(st.st_mtime)}".encode())
        except OSError:
            h.update(f"|{p}|missing".encode())
    for u in RAG_URLS:
        h.update(("|" + u.strip()).encode())
    h.update("|".join(sorted(_state["ops"].keys())).encode())
    return h.hexdigest()[:16]


# Provider settings (key/model) stay in a small local JSON file — they are
# per-deployment configuration, not per-user conversation data.
DATA_DIR = os.environ.get("DATA_DIR", os.path.expanduser("~/.local/share/pf-chatbot"))

# ── runtime provider settings (UI-overridable; .env is the static default) ──
_cfg_lock = threading.Lock()


def _settings_path() -> str:
    return os.path.join(DATA_DIR, "settings.json")


def _load_overrides() -> dict:
    try:
        with open(_settings_path(), "r", encoding="utf-8") as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def _save_overrides(d: dict) -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    path = _settings_path()
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(d, f)
    os.replace(tmp, path)
    try:
        os.chmod(path, 0o600)  # holds an API key
    except OSError:
        pass


def _clear_overrides() -> None:
    try:
        os.remove(_settings_path())
    except OSError:
        pass


def _effective_config() -> dict:
    """Env defaults overlaid with any UI-saved overrides."""
    cfg = {"provider": PROVIDER, "api_key": API_KEY, "model": MODEL, "source": "env"}
    ov = _load_overrides()
    if ov.get("provider") and ov.get("api_key"):
        cfg.update(
            provider=ov["provider"], api_key=ov["api_key"],
            model=ov.get("model") or None, source="override",
        )
    return cfg


def _test_api_key(provider_name: str, api_key: str, model: str | None) -> dict:
    """Test an API key by making one lightweight authenticated call to the
    provider (list its models). Returns {'ok': True, 'models': N} on success, or
    {'ok': False, 'error': <concise reason>} with the exact cause."""
    import httpx
    try:
        prov = providers.build(provider_name, api_key, model, http)
    except Exception as e:
        return {"ok": False, "error": f"could not initialize provider: {e}"}
    if not hasattr(prov, "list_models"):
        return {"ok": False, "error": "provider cannot be tested"}
    try:
        models = prov.list_models()
        return {"ok": True, "models": len(models),
                "detail": f"key valid — {len(models)} model(s) available"}
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        # pull the provider's own error message when present
        detail = ""
        try:
            body = e.response.json()
            detail = (body.get("error", {}) or {}).get("message") or body.get("message") or ""
        except Exception:
            detail = (e.response.text or "")[:200]
        reason = {
            401: "invalid or revoked API key",
            403: "key lacks permission for this provider/endpoint",
            429: "rate limited or quota exceeded",
            500: "provider server error",
            503: "provider temporarily unavailable",
        }.get(code, f"HTTP {code}")
        msg = f"{reason}" + (f" — {detail}" if detail else "")
        return {"ok": False, "error": msg, "status": code}
    except httpx.TimeoutException:
        return {"ok": False, "error": "timed out contacting the provider"}
    except httpx.ConnectError:
        return {"ok": False, "error": "could not reach the provider (network/DNS)"}
    except Exception as e:
        return {"ok": False, "error": f"unexpected error: {e}"}


def _apply_provider(cfg: dict) -> None:
    """Build and activate a provider from a config dict. Raises on bad input."""
    prov = providers.build(cfg["provider"], cfg["api_key"], cfg.get("model"), http)
    _state["provider"] = prov
    _state["cfg"] = {
        "provider": cfg["provider"], "api_key": cfg["api_key"],
        "model": prov.model, "source": cfg.get("source", "override"),
    }
    print(f"[pf-bot] provider={cfg['provider']} model={prov.model} (config: {cfg.get('source')})")


def _init_reranker():
    if not RAG_RERANK or _state.get("reranker") is not None:
        return
    try:
        from rag.embedder import Reranker
        _state["reranker"] = Reranker(RAG_RERANK)
        print(f"[pf-bot] reranker enabled: {RAG_RERANK}")
    except Exception as e:
        print(f"[pf-bot] reranker init failed (continuing without): {e}")


def build_rag():
    """Build the in-memory RAG index: OpenAPI ops + local files + URLs.
    Embeddings are cached on disk keyed by a corpus signature, so unchanged
    corpora load in seconds instead of re-embedding on every restart."""
    try:
        embedder = Embedder(model_name=RAG_EMBED) if RAG_EMBED else Embedder()
    except Exception as e:
        print(f"[pf-bot] RAG disabled (embedder init failed): {e}")
        return
    index = Index()
    sig = _rag_signature()
    docs_path = os.path.join(RAG_CACHE_DIR, f"rag-{sig}.json")
    vecs_path = os.path.join(RAG_CACHE_DIR, f"rag-{sig}.npy")

    if os.path.isfile(docs_path) and os.path.isfile(vecs_path):
        try:
            with open(docs_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
            vectors = np.load(vecs_path)
            if len(raw) == vectors.shape[0]:
                index.docs = [Document(**d) for d in raw]
                index.vectors = vectors.astype(np.float32)
                _state["embedder"] = embedder
                _state["rag"] = index
                _init_reranker()
                print(f"[pf-bot] RAG loaded from cache: {len(index.docs)} chunks (sig {sig})")
                return
            print("[pf-bot] RAG cache inconsistent; rebuilding")
        except Exception as e:
            print(f"[pf-bot] RAG cache load failed ({e}); rebuilding")

    op_docs = load_openapi_operations(_state["ops"])
    file_docs = load_local_files(RAG_FILES)
    url_docs = load_urls(RAG_URLS, http)
    total = len(op_docs) + len(file_docs) + len(url_docs)
    print(f"[pf-bot] RAG cache miss (sig {sig}) — building index: "
          f"{len(op_docs)} ops + {len(file_docs)} doc chunks + {len(url_docs)} url chunks "
          f"= {total} to embed. First boot after a change is slow; "
          f"restarts then load from cache in ~1s.", flush=True)
    t_embed = time.time()
    for group, what in ((op_docs, "API operations"), (file_docs, "doc chunks"),
                        (url_docs, "url chunks")):
        if group:
            index.add(group, embedder, label=what)
    print(f"[pf-bot] embedding finished in {time.time() - t_embed:.0f}s", flush=True)
    _state["embedder"] = embedder
    _state["rag"] = index
    _init_reranker()
    print(
        f"[pf-bot] RAG indexed {len(op_docs)} ops, {len(file_docs)} file chunks, "
        f"{len(url_docs)} url chunks"
    )
    try:
        os.makedirs(RAG_CACHE_DIR, exist_ok=True)
        with open(docs_path, "w", encoding="utf-8") as f:
            json.dump(
                [{"text": d.text, "source_type": d.source_type, "meta": d.meta} for d in index.docs],
                f,
            )
        np.save(vecs_path, index.vectors)
        print(f"[pf-bot] RAG cache saved to {RAG_CACHE_DIR} (sig {sig})")
    except Exception as e:
        print(f"[pf-bot] RAG cache save failed (non-fatal): {e}")


# ── tool implementations ─────────────────────────────────────────────────────
_ID_SPLIT_RE = re.compile(r"[._/:\-]+")
_CAMEL_RE = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")
_QWORD_RE = re.compile(r"[a-z0-9]+")
# words that carry no signal about WHICH resource is wanted
_STOP = {"all", "the", "a", "an", "list", "show", "get", "find", "display", "give",
         "me", "of", "for", "in", "on", "to", "please", "current", "every", "any"}


def _op_tokens(o: dict) -> set[str]:
    """Words hidden inside an operation id and path.

    'api.v1.Config.Source.list' + '/config/sources' -> {api,v1,config,source,
    sources,list}. Doing this at query time means the resource noun is findable
    without re-embedding the corpus."""
    raw = f"{o.get('id','')} {o.get('path','')}"
    raw = re.sub(r"\{[^}]*\}", " ", raw)          # drop path params entirely
    out: set[str] = set()
    for part in _ID_SPLIT_RE.split(raw):
        part = part.strip()
        if not part:
            continue
        for w in _CAMEL_RE.split(part):
            w = w.strip().lower()
            if not w:
                continue
            out.add(w)
            out.add(w[:-1] if w.endswith("s") else w + "s")   # both number forms
    return out


def _substring_search(query: str, limit: int = 12) -> list[dict]:
    """Lexical operation search.

    Used as the RAG fallback AND blended into every search, so an operation
    whose id or path literally contains a query word can never be missed —
    which is how 'authentication sources' used to fail to reach /config/sources
    while plain 'sources' worked."""
    words = [w for w in _QWORD_RE.findall((query or "").lower()) if w not in _STOP]
    if not words:
        return []
    scored = []
    for o in _state["ops"].values():
        toks = _op_tokens(o)
        path = (o.get("path") or "").lower()
        segs = [p for p in path.split("/") if p and not p.startswith("{")]
        noun = segs[-1] if segs else ""
        noun_forms = {noun, noun[:-1] if noun.endswith("s") else noun + "s"}
        score = 0
        matched = 0
        for w in words:
            if w in noun_forms:
                score += 12          # the resource itself — the strongest signal
                matched += 1
            elif w in toks:
                score += 5           # appears somewhere in the id/path
                matched += 1
            elif len(w) > 4 and any(w in t or t in w for t in toks):
                score += 2           # partial, e.g. 'profile' vs 'profiles'
                matched += 1
        if not matched:
            continue
        score += 3 * matched                     # reward covering more of the query
        if len(segs) <= 2:
            score += 2                           # prefer top-level resources
        if "{" not in (o.get("path") or ""):
            score += 1                           # a collection beats an item view
        hay = " ".join([o.get("summary", ""), o.get("description", "")]).lower()
        score += sum(1 for w in words if w in hay)
        scored.append((score, o))
    scored.sort(key=lambda x: (-x[0], x[1]["id"]))
    return [{"operation_id": o["id"], "method": o["method"].upper(), "path": o["path"],
             "summary": o.get("summary", ""), "is_write": o.get("is_write", False),
             "score": round(sc / 20, 4)}
            for sc, o in scored[:limit]]


def search_ops(query: str, limit: int = 12) -> list[dict]:
    """Find candidate API operations for a natural-language query.

    Fuses two rankings with Reciprocal Rank Fusion rather than concatenating
    them. Concatenating let a noisy semantic hit outrank the right answer:
    'authentication sources' put SecurityEvents.list first even though the
    lexical pass had /config/sources at rank 1. With RRF an operation both
    halves like beats one that only one half likes."""
    limit = max(int(limit or 12), 12)          # a tiny top-k starves the model
    rag = _state.get("rag")
    embedder = _state.get("embedder")

    lists: list[list[dict]] = []
    if rag and embedder and len(rag):
        lists.append([{"operation_id": h["meta"]["operation_id"],
                       "method": h["meta"]["method"], "path": h["meta"]["path"],
                       "summary": h["meta"]["summary"], "is_write": h["meta"]["is_write"]}
                      for h in rag.search(query, embedder, k=limit * 2,
                                          source_types=["operation"])])
    lists.append(_substring_search(query, limit * 2))

    K = 60.0                                   # standard RRF damping
    fused: dict[str, dict] = {}
    scores: dict[str, float] = {}
    for hits in lists:
        for rank, h in enumerate(hits, start=1):
            oid = h["operation_id"]
            fused.setdefault(oid, h)
            scores[oid] = scores.get(oid, 0.0) + 1.0 / (K + rank)
    out = []
    for oid in sorted(scores, key=lambda o: (-scores[o], o)):
        d = dict(fused[oid])
        d["score"] = round(scores[oid], 5)
        out.append(d)
    return out[:limit]


def search_docs(query: str, limit: int = 6) -> list[dict]:
    rag = _state.get("rag")
    embedder = _state.get("embedder")
    if not rag or not embedder or len(rag) == 0:
        return []
    hits = rag.search(query, embedder, k=limit, source_types=["file:", "url:"],
                      reranker=_state.get("reranker"))
    return [{"source": h["source_type"], "text": h["text"], "score": round(h["score"], 4)} for h in hits]


def describe(oid: str) -> dict:
    o = _state["ops"].get(oid)
    if not o:
        return {"error": f"Unknown operation_id '{oid}'. Search first."}
    return {"operation_id": o["id"], "method": o["method"].upper(), "path": o["path"], "summary": o["summary"],
            "is_write": o["is_write"], "description": o["description"],
            "parameters": o["parameters"], "request_body": o["requestBody"]}


def build_url(path: str) -> str:
    prefix = urlsplit(PF_BASE_URL).path
    if prefix and path.startswith(prefix + "/"):
        s = urlsplit(PF_BASE_URL)
        return f"{s.scheme}://{s.netloc}{path}"
    return PF_BASE_URL + path


def _curl_for(method: str, url: str, query_params=None, body=None,
              has_auth: bool = False) -> str:
    """Reconstruct an equivalent, copy-pasteable curl command for an API call.
    The Authorization token is shown as a placeholder, never the real secret."""
    import shlex
    full = url
    if query_params:
        qs = urlencode(query_params, doseq=True)
        full = f"{url}?{qs}"
    parts = ["curl", "-sS", "-X", method.upper(), shlex.quote(full)]
    if has_auth:
        parts += ["-H", shlex.quote("Authorization: $PF_TOKEN")]
    if body is not None:
        parts += ["-H", shlex.quote("Content-Type: application/json")]
        parts += ["-d", shlex.quote(json.dumps(body))]
    if VERIFY_TLS is False:
        parts.append("-k")
    return " ".join(parts)


def _readback(oid: str, path_params=None) -> dict | None:
    """After a write, GET the same path and return the record.

    PacketFence answers a PATCH with {"message": "'<mac>' updated", "status": 200}
    whether or not anything changed — an unknown field name is accepted and
    silently ignored. Reading the record back is the only way to tell a real
    update from a no-op."""
    o = _state.get("ops", {}).get(oid)
    if not o:
        return None
    path = o.get("path", "")
    for get_oid, g in (_state.get("ops", {}) or {}).items():
        if g.get("method", "").lower() == "get" and g.get("path") == path:
            res = invoke(get_oid, path_params=path_params)
            if isinstance(res, dict) and res.get("status_code") == 200:
                body = res.get("body")
                if isinstance(body, dict) and "item" in body:
                    body = body["item"]
                return {"operation_id": get_oid, "record": body}
            return {"operation_id": get_oid, "error": f"read-back HTTP {res.get('status_code')}"}
    return None


def invoke(oid: str, path_params=None, query_params=None, body=None,
           confirmed: bool = False) -> dict:
    o = _state["ops"].get(oid)
    if not o:
        return {"error": f"Unknown operation_id '{oid}'."}

    # ── write guard ──────────────────────────────────────────────────────────
    # Mutating operations are NOT executed on the agent's say-so. We pend them
    # and return a confirmation request; the UI shows a dialog and the actual
    # call only runs after the user approves it via /confirm_write. This makes it
    # impossible for the model to change production state without a human click.
    if o["is_write"] and not confirmed:
        token = uuid.uuid4().hex[:16]
        _pending_writes[token] = {
            "oid": oid, "path_params": path_params, "query_params": query_params,
            "body": body, "created": time.time(),
        }
        # best-effort human-readable path preview
        preview = o["path"]
        for k, v in (path_params or {}).items():
            preview = preview.replace("{" + k + "}", str(v))
        return {
            "confirmation_required": True,
            "confirm_token": token,
            "operation_id": oid,
            "method": o["method"].upper(),
            "path": preview,
            "summary": o.get("summary", ""),
            "note": "This is a write operation. It has NOT run yet — the user must "
                    "confirm it in the UI. Tell the user what will happen and that "
                    "they need to confirm.",
        }

    path = o["path"]
    for k, v in (path_params or {}).items():
        # safe=":" so a MAC stays 02:00:00:00:00:01 rather than becoming
        # 02%3A00%3A... — PacketFence's node paths use the colons literally
        path = path.replace("{" + k + "}", quote(str(v), safe=":"))
    url = build_url(path)
    sent_body = body if o["is_write"] else None
    curl = _curl_for(o["method"], url, query_params, sent_body, has_auth=bool(_state["token"]))
    def do():
        return http.request(o["method"].upper(), url, params=query_params or None,
                            json=sent_body, headers=auth())
    r = do()
    if r.status_code == 401 and PF_USERNAME:
        login(); r = do()
    try:
        data = r.json()
    except Exception:
        data = r.text[:4000]
    return {"status_code": r.status_code, "method": o["method"].upper(), "path": path,
            "curl": curl, "body": data}


# ── neutral tool schemas + dispatch ──────────────────────────────────────────
# ── log search (read-only, MAC-scoped) ───────────────────────────────────────
# Logs are mounted read-only into the container at /pflogs (see pf-chatbot.service).
# Only these fixed files are searchable; the tool never takes an arbitrary path.
PF_LOG_DIR = os.environ.get("PF_LOG_DIR", "/pflogs")
_LOG_FILES = {
    "radius": "radius.log",
    "packetfence": "packetfence.log",
}
_MAC_RE = re.compile(r"^[0-9A-Fa-f]{2}([:\-]?[0-9A-Fa-f]{2}){5}$")
# Usernames as they appear in 802.1X/EAP: letters, digits, and the punctuation
# real identities use (dot, dash, underscore, @, /, \ for host/domain forms).
# Deliberately excludes spaces, quotes, and shell metacharacters.
_USER_RE = re.compile(r"^[A-Za-z0-9._@/\\\-]{1,128}$")
# how many trailing lines of each log to consider (bounds cost on huge logs)
_LOG_TAIL_LINES = int(os.environ.get("PF_LOG_TAIL", "200000"))


def _mac_variants(mac: str) -> list[str]:
    """All formats PacketFence might log a MAC in, from the canonical hex."""
    hexd = re.sub(r"[^0-9a-fA-F]", "", mac).lower()
    if len(hexd) != 12:
        return []
    pairs = [hexd[i:i + 2] for i in range(0, 12, 2)]
    return [
        ":".join(pairs),          # aa:bb:cc:dd:ee:ff
        "-".join(pairs),          # aa-bb-cc-dd-ee-ff
        hexd,                     # aabbccddeeff
        ".".join([hexd[i:i + 4] for i in range(0, 12, 4)]),  # aabb.ccdd.eeff (cisco)
    ]


def _format_recent_logs(logs: dict, caps: dict | None = None, default_cap: int = 20) -> str:
    """Build a plain-text block of the most recent matching log lines, per file,
    for verbatim display. Lines already carry their native timestamps. `caps`
    maps a log name to how many trailing lines to show (radius is terse verdicts,
    packetfence carries the verbose policy trail), falling back to default_cap."""
    if not isinstance(logs, dict) or not logs:
        return "(no matching log lines)"
    caps = caps or {}
    order = ["radius", "packetfence"]
    names = order + [k for k in logs if k not in order]
    sections: list[str] = []
    for name in names:
        grp = logs.get(name)
        if not isinstance(grp, dict):
            continue
        if grp.get("error"):
            sections.append(f"# {name}.log: {grp['error']}")
            continue
        lines = grp.get("lines") or []
        if not lines:
            sections.append(f"# {name}.log: no matches")
            continue
        cap = caps.get(name, default_cap)
        recent = lines[-cap:]
        header = f"# {name}.log — last {len(recent)} matching line(s)"
        if grp.get("match_count", 0) > len(recent):
            header += f" (of {grp['match_count']} total)"
        sections.append(header + "\n" + "\n".join(recent))
    return "\n\n".join(sections) if sections else "(no matching log lines)"


# how many trailing radius verdict lines to show in diagnose/search output
_LOG_CAPS = {"radius": 8, "packetfence": 25}

# markers for a single RADIUS authorization attempt in packetfence.log
_AUTZ_START = re.compile(r"handling radius autz request", re.I)
_AUTZ_END = re.compile(r"returned RADIUS Access-(Accept|Reject)", re.I)


def _latest_autz_block(pf_lines: list) -> list:
    """Return the lines of the MOST RECENT authorization attempt in
    packetfence.log \u2014 from the last 'handling radius autz request' up to (and
    including) the 'returned RADIUS Access-*' line, plus up to 2 trailing lines.
    Returns [] if no start marker is found."""
    lines = pf_lines or []
    start = None
    for i in range(len(lines) - 1, -1, -1):
        if _AUTZ_START.search(lines[i]):
            start = i
            break
    if start is None:
        return []
    end = len(lines) - 1
    for j in range(start, len(lines)):
        if _AUTZ_END.search(lines[j]):
            end = min(j + 2, len(lines) - 1)
            break
    return lines[start:end + 1]


def _attrs_from_autz_block(block: list) -> dict:
    """Parse the attributes PacketFence logged for one attempt: MAC, connection
    type, switch IP, profile, auth source, status, role, VLAN, and RADIUS result."""
    attrs: dict = {}
    for ln in block:
        m = re.search(r"connection_type => ([\w\-\.]+)", ln)
        if m and "connection_type" not in attrs:
            attrs["connection_type"] = m.group(1)
        m = re.search(r'username => "([^"]*)"', ln)
        if m and "username" not in attrs:
            attrs["username"] = m.group(1)
        # MAC appears as "mac => [aa:bb:..]" or "[mac:aa:bb:..]"
        m = re.search(r"mac => \[?([0-9A-Fa-f:]{17})\]?", ln) or re.search(r"\[mac:([0-9A-Fa-f:]{17})\]", ln)
        if m and "mac" not in attrs:
            attrs["mac"] = m.group(1)
        # switch / NAS IP: "switch_ip => (1.2.3.4)"
        m = re.search(r"switch_ip => \(?([0-9.]+)\)?", ln)
        if m and "switch_ip" not in attrs:
            attrs["switch_ip"] = m.group(1)
        m = re.search(r"Instantiate profile (\w+)", ln)
        if m and "profile" not in attrs:
            attrs["profile"] = m.group(1)
        # authentication source, e.g. "source(s) ... 'local'" / "matched ... source X"
        m = (re.search(r"authentication source[s]?[^A-Za-z0-9]+['\"]?([\w\-]+)", ln, re.I)
             or re.search(r"using (?:auth )?source ['\"]?([\w\-]+)", ln, re.I)
             or re.search(r"matched (?:in )?(?:the )?source ['\"]?([\w\-]+)", ln, re.I))
        if m and "auth_source" not in attrs:
            attrs["auth_source"] = m.group(1)
        m = re.search(r"is of status (\w+)", ln)
        if m and "status" not in attrs:
            attrs["status"] = m.group(1)
        m = re.search(r"belongs into (.+?) (?:VLAN|role)", ln, re.I)
        if m and "role_reason" not in attrs:
            attrs["role_reason"] = m.group(1).strip()
        # explicit role, e.g. "role: staff" / "Returning role (staff)"
        m = (re.search(r"[Rr]eturning role \(?([\w\-]+)\)?", ln)
             or re.search(r"\brole[:=] ?['\"]?([\w\-]+)", ln))
        if m and "role" not in attrs:
            attrs["role"] = m.group(1)
        m = re.search(r"Added VLAN (\w+) to the returned RADIUS Access-(\w+)", ln)
        if m:
            attrs["vlan"] = m.group(1)
            attrs["result"] = "Access-" + m.group(2)
        else:
            m = re.search(r"returned RADIUS Access-(\w+)", ln)
            if m and "result" not in attrs:
                attrs["result"] = "Access-" + m.group(1)
    return attrs


def _format_diagnose_logs(logs: dict, latest_block: list) -> str:
    """Diagnose display: recent radius verdict lines + the packetfence lines for
    just the LATEST attempt (not the whole noisy tail)."""
    sections: list = []
    rad = logs.get("radius") if isinstance(logs, dict) else None
    if isinstance(rad, dict):
        if rad.get("error"):
            sections.append("# radius.log: " + str(rad["error"]))
        else:
            lines = (rad.get("lines") or [])[-_LOG_CAPS["radius"]:]
            if lines:
                hdr = f"# radius.log \u2014 last {len(lines)} matching line(s)"
                if rad.get("match_count", 0) > len(lines):
                    hdr += f" (of {rad['match_count']} total)"
                sections.append(hdr + "\n" + "\n".join(lines))
            else:
                sections.append("# radius.log: no matches")
    if latest_block:
        sections.append("# packetfence.log \u2014 latest authentication attempt\n"
                        + "\n".join(latest_block))
    elif isinstance(logs.get("packetfence"), dict) and logs["packetfence"].get("error"):
        sections.append("# packetfence.log: " + str(logs["packetfence"]["error"]))
    else:
        sections.append("# packetfence.log: no authorization attempt found")
    return "\n\n".join(sections) if sections else "(no matching log lines)"
def search_logs(mac: str = "", which: str = "both", limit: int = 80,
                username: str = "") -> dict:
    """Grep the PacketFence logs for a MAC (all format-variants) OR a username,
    returning matching lines (most recent last). Read-only, fixed files, capped
    output. Exactly one of `mac` or `username` should be given."""
    mac = (mac or "").strip()
    username = (username or "").strip()

    if mac and username:
        return {"error": "provide either a MAC or a username, not both"}
    if not mac and not username:
        return {"error": "a MAC address or username is required"}

    if mac:
        if not _MAC_RE.match(mac):
            return {"error": "a valid MAC address is required (e.g. aa:bb:cc:dd:ee:ff)"}
        terms = _mac_variants(mac)
        if not terms:
            return {"error": "could not parse MAC"}
        subject = {"kind": "mac", "value": mac, "matched_formats": terms}
    else:
        if not _USER_RE.match(username):
            return {"error": "invalid username (letters, digits and . _ - @ / \\ only)"}
        # Match the bare username and common logged forms: quoted, and
        # User-Name = "x" as RADIUS logs it. grep -F treats each as a literal.
        terms = [username, f'"{username}"', f"User-Name = {username}"]
        subject = {"kind": "username", "value": username}

    targets = []
    if which in ("radius", "both"):
        targets.append(("radius", _LOG_FILES["radius"]))
    if which in ("packetfence", "both"):
        targets.append(("packetfence", _LOG_FILES["packetfence"]))
    if not targets:
        targets = [(k, v) for k, v in _LOG_FILES.items()]

    limit = max(1, min(int(limit or 80), 300))
    out: dict = {**subject, "logs": {}}
    # build one grep -F with all terms; -a treats binary-ish lines as text
    grep_args = []
    for t in terms:
        grep_args += ["-e", t]

    for name, fname in targets:
        path = os.path.join(PF_LOG_DIR, fname)
        if not os.path.isfile(path):
            out["logs"][name] = {"error": f"log not found at {path} (is it mounted?)"}
            continue
        try:
            # tail the file first to bound work on multi-GB logs, then grep,
            # then keep only the last `limit` matches. All read-only.
            tail = subprocess.run(
                ["tail", "-n", str(_LOG_TAIL_LINES), path],
                capture_output=True, text=True, timeout=20,
            )
            grep = subprocess.run(
                ["grep", "-aF", *grep_args],
                input=tail.stdout, capture_output=True, text=True, timeout=20,
            )
            lines = [ln for ln in grep.stdout.splitlines() if ln.strip()]
            out["logs"][name] = {
                "match_count": len(lines),
                "lines": lines[-limit:],
                "truncated": len(lines) > limit,
            }
        except subprocess.TimeoutExpired:
            out["logs"][name] = {"error": "log search timed out"}
        except Exception as e:
            out["logs"][name] = {"error": f"log search failed: {e}"}
    out["recent_log_block"] = _format_recent_logs(out["logs"], caps=_LOG_CAPS)
    out["_guidance"] = (
        "Show the matching log lines from 'recent_log_block' EXACTLY, inside a "
        "fenced code block under a 'Recent log entries' heading. Then give a brief "
        "analysis: the latest authentication result (from the last radius line) and "
        "the overall pattern across the recent lines."
    )
    return out


# PacketFence exposes the single-node endpoint as /node/{id} (SINGULAR) — e.g.
# GET /api/v1/node/aa:bb:cc:dd:ee:ff — while collections live at /nodes.
# Matching only "/nodes/{" silently found nothing, so accept either.
_PATH_PARAM_RE = re.compile(r"\{[^}]+\}")


def _score_item_op(o: dict, resource: str) -> int:
    """Rank a candidate 'fetch one <resource>' operation. Higher is better;
    negative means unusable.

    The trap this exists for: /configurator/user/{user_id}/node/{node_id} also
    ends in /node/{...}, so a naive suffix match picks it, drops the MAC into
    the *user* slot and leaves {node_id} unsubstituted."""
    if o.get("method", "").lower() != "get":
        return -1
    path = o.get("path", "") or ""
    params = _PATH_PARAM_RE.findall(path)
    # exactly one path parameter — anything else is a nested resource
    if len(params) != 1:
        return -1
    # the parameter must be the LAST segment: /node/{id} not /node/{id}/violations
    if not re.search(r"/" + resource + r"s?/\{[^/}]+\}$", path):
        return -1
    segments = [p for p in path.strip("/").split("/") if p]
    # canonical is /<resource>/{id} — two segments. Deeper means it hangs off
    # something else (configurator, user, tenant ...), which is not what we want.
    score = 100 - (len(segments) - 2) * 40
    if "configurator" in path:
        score -= 100
    return score


def _node_view_ops() -> list[str]:
    """Operation ids that fetch ONE node, best first. Known ids are tried before
    anything discovered from the spec so behaviour stays predictable."""
    ops = _state.get("ops", {}) or {}
    out: list[str] = []
    for oid in ("api.v1.Node.get", "api.v1.Nodes.get", "api.v1.Node.view",
                "api.v1.Nodes.view", "api.v1.NodeView", "api.v1.Node.read"):
        if oid in ops and _score_item_op(ops[oid], "node") >= 0:
            out.append(oid)
    scored = []
    for oid, o in ops.items():
        if oid in out:
            continue
        sc = _score_item_op(o, "node")
        if sc >= 0:
            scored.append((sc, oid))
    scored.sort(key=lambda x: (-x[0], x[1]))
    out += [oid for _, oid in scored]
    return out


def _plural_candidates(base: str) -> list[str]:
    """English-ish plurals, best first. 'switch' -> 'switches', not 'switchs'."""
    tail = base.rstrip("/").rsplit("/", 1)[-1]
    if not tail:
        return [base]
    stem = base[: len(base) - len(tail)]
    out = [base]                                   # already plural?
    if tail.endswith(("s", "x", "z", "ch", "sh")):
        out.append(stem + tail + "es")
    elif tail.endswith("y") and len(tail) > 1 and tail[-2] not in "aeiou":
        out.append(stem + tail[:-1] + "ies")
    else:
        out.append(stem + tail + "s")
    return out


def _node_categories_op() -> str | None:
    """The GET operation that lists node categories (roles)."""
    ops = _state.get("ops", {}) or {}
    for oid, o in ops.items():
        if o.get("method", "").lower() == "get" and o.get("path") == "/node_categories":
            return oid
    for oid, o in ops.items():
        if (o.get("method", "").lower() == "get"
                and "node_categor" in (o.get("path") or "").lower()
                and "{" not in (o.get("path") or "")):
            return oid
    return None


def _fetch_roles() -> list[dict]:
    """Roles with their NUMERIC category_id.

    GET /api/v1/node_categories returns both the id and the name (the config
    roles endpoint returns the name AS the id, which is what made role changes
    fail). Falls back to reading node_category directly only if that operation
    isn't in the spec."""
    oid = _node_categories_op()
    if oid:
        res = invoke(oid, query_params={"limit": 1000})
        if isinstance(res, dict) and res.get("status_code") == 200:
            body = res.get("body") or {}
            items = body.get("items") if isinstance(body, dict) else None
            if isinstance(items, list):
                out = []
                for it in items:
                    if not isinstance(it, dict):
                        continue
                    cid, nm = it.get("category_id"), it.get("name")
                    if cid is None or nm is None:
                        continue
                    try:
                        cid = int(str(cid).strip())      # PF returns them as strings
                    except ValueError:
                        continue
                    out.append({"category_id": cid, "name": str(nm),
                                "notes": it.get("notes")})
                if out:
                    return sorted(out, key=lambda r: r["category_id"])
    try:                                                  # fallback: read the table
        return store.roles()
    except Exception as e:
        return [{"error": f"could not list roles: {e}"}]


def list_roles(name: str = "") -> dict:
    """Roles and their numeric ids, so a role NAME can be turned into the
    category_id a node PATCH requires."""
    all_roles = _fetch_roles()
    if all_roles and isinstance(all_roles[0], dict) and all_roles[0].get("error"):
        return {"error": all_roles[0]["error"],
                "hint": "the node_categories operation was not found and the database "
                        "fallback failed"}
    want = (name or "").strip()
    if want:
        if want.isdigit():
            rid = int(want)
        else:
            rid = next((r["category_id"] for r in all_roles
                        if r["name"].lower() == want.lower()), None)
        if rid is None:
            return {"error": f"no role named {want!r}",
                    "available": [r["name"] for r in all_roles]}
        return {"name": want, "category_id": rid,
                "_guidance": f"Send category_id={rid} (a number, not a string) in the "
                             f"node PATCH body."}
    return {"roles": all_roles,
            "_guidance": "A node PATCH needs category_id as a NUMBER. Match the role the "
                         "user named against 'name' and send its category_id."}


def _collection_path(path: str) -> str:
    """Turn an item path into its collection: /node/{id} -> /nodes.
    PacketFence exposes field metadata on the collection endpoint.

    Prefers a path that actually exists in the OpenAPI spec over a guessed
    plural, because naive pluralisation gets /config/switch wrong (the real
    collection is /config/switches, not /config/switchs)."""
    base = re.sub(r"/\{[^}]+\}$", "", path or "")
    if not base:
        return "/"
    known = {o.get("path", "") for o in (_state.get("ops", {}) or {}).values()}
    for cand in _plural_candidates(base):
        if cand in known:
            return cand
    return _plural_candidates(base)[-1]


def options_meta(target: str) -> dict:
    """Ask PacketFence what a resource's fields are, via OPTIONS.

    PF answers OPTIONS on a collection with a schema describing each field:
    its type, whether it is required, and any validation pattern. Reading that
    before a write means we send the right fields in the right format instead
    of guessing and getting a 422."""
    target = (target or "").strip()
    if not target:
        return {"error": "an operation_id or path is required"}
    # tolerate what the model actually passes: 'PATCH /node/{mac}', a bare path
    # with differently-named params, or an operation_id that isn't in the spec
    target = re.sub(r"^(GET|POST|PUT|PATCH|DELETE|OPTIONS)\s+", "", target, flags=re.I).strip()
    ops = _state.get("ops", {}) or {}
    op = ops.get(target)
    path = op["path"] if op else target
    if not path.startswith("/"):
        # last resort: match an operation whose id ends with the given fragment
        frag = target.lower()
        cand = [oid for oid in ops if oid.lower().endswith(frag) or frag in oid.lower()]
        if cand:
            path = ops[cand[0]]["path"]
        else:
            return {"error": f"unknown operation_id or path {target!r}",
                    "hint": "pass an operation_id from pf_search_operations, or a path like /nodes"}
    # normalise a param name we do not have ({mac} vs {node_id}) to the spec's path
    if "{" in path and path not in {o.get("path") for o in ops.values()}:
        stem = re.sub(r"\{[^}]*\}", "{}", path)
        for o in ops.values():
            if re.sub(r"\{[^}]*\}", "{}", o.get("path", "")) == stem:
                path = o["path"]
                break
    coll = _collection_path(path)
    url = build_url(coll)
    try:
        r = http.request("OPTIONS", url, headers=auth())
        if r.status_code == 401 and PF_USERNAME:
            login()
            r = http.request("OPTIONS", url, headers=auth())
    except Exception as e:
        return {"error": f"OPTIONS {coll} failed: {e}"}
    if r.status_code >= 400:
        return {"error": f"OPTIONS {coll} returned HTTP {r.status_code}",
                "status_code": r.status_code, "path": coll}
    try:
        body = r.json()
    except Exception:
        return {"error": "OPTIONS response was not JSON", "path": coll}

    # PF nests the field map under "meta" (sometimes below a resource key).
    meta = body.get("meta") if isinstance(body, dict) else None
    if isinstance(meta, dict) and len(meta) == 1:
        only = next(iter(meta.values()))
        if isinstance(only, dict) and any(
                isinstance(v, dict) and ("type" in v or "required" in v) for v in only.values()):
            meta = only
    fields = []
    if isinstance(meta, dict):
        for name, spec in meta.items():
            if not isinstance(spec, dict):
                continue
            f = {"name": name, "type": spec.get("type"),
                 "required": bool(spec.get("required"))}
            for k_src, k_dst in (("pattern", "pattern"), ("placeholder", "example"),
                                 ("default", "default"), ("min_length", "min_length"),
                                 ("max_length", "max_length")):
                v = spec.get(k_src)
                if isinstance(v, dict):
                    v = v.get("regex") or v.get("pattern") or v.get("message") or None
                if v not in (None, ""):
                    f[k_dst] = v
            allowed = spec.get("allowed") or spec.get("options") or spec.get("enum")
            if isinstance(allowed, list) and allowed:
                vals = []
                for a in allowed[:40]:
                    vals.append(a.get("value") if isinstance(a, dict) else a)
                f["allowed"] = vals
            fields.append(f)
    out = {"path": coll, "field_count": len(fields),
           "required": [f["name"] for f in fields if f.get("required")],
           "fields": fields}
    if not fields:
        out["raw"] = body if len(json.dumps(body, default=str)) < 4000 else "(too large)"
        out["note"] = "no field metadata recognised; showing the raw OPTIONS body"
    else:
        out["_guidance"] = ("Send exactly the required fields, respect any 'pattern' "
                            "and pick values from 'allowed' where present.")
    return out


def _node_update_ops() -> list[str]:
    """Operation ids that update ONE node, best first. Same scoring as the read
    path — exactly one path parameter, at the end, canonical depth — so a nested
    or unrelated write endpoint can never be picked."""
    ops = _state.get("ops", {}) or {}
    out: list[str] = []
    for oid in ("api.v1.Node.update", "api.v1.Nodes.update", "api.v1.Node.patch",
                "api.v1.Node.replace"):
        o = ops.get(oid)
        if o and _PATH_PARAM_RE.findall(o.get("path", "")) and oid not in out:
            out.append(oid)
    scored = []
    for oid, o in ops.items():
        if oid in out or o.get("method", "").lower() not in ("patch", "put"):
            continue
        path = o.get("path", "") or ""
        if len(_PATH_PARAM_RE.findall(path)) != 1:
            continue
        if not re.search(r"/nodes?/\{[^/}]+\}$", path):
            continue
        segs = [p for p in path.strip("/").split("/") if p]
        score = 100 - (len(segs) - 2) * 40 - (100 if "configurator" in path else 0)
        # PATCH is a partial update, which is what we want for one field
        if o.get("method", "").lower() == "patch":
            score += 5
        scored.append((score, oid))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return out + [oid for _, oid in scored]


def _node_action_ops(action: str) -> list[str]:
    """Operation ids for a node SUB-ACTION, e.g. /node/{id}/reevaluate_access.

    Deterministic, because semantic search does not reliably surface these —
    it matches the resource noun ("node") and returns the CRUD endpoints, so
    the model concludes no such endpoint exists and suggests a workaround."""
    ops = _state.get("ops", {}) or {}
    want = (action or "").strip().lower()
    scored = []
    for oid, o in ops.items():
        path = (o.get("path") or "").lower()
        if o.get("method", "").lower() not in ("post", "put", "patch"):
            continue
        if not re.search(r"/nodes?/\{[^/}]+\}/" + re.escape(want) + r"$", path):
            continue
        if len(_PATH_PARAM_RE.findall(o.get("path", ""))) != 1:
            continue
        score = 100 - (100 if "configurator" in path else 0)
        scored.append((score, oid))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [oid for _, oid in scored]


def _stage_node_write(mac: str, oid: str, body: dict | None, summary: str):
    """Prepare a node write for the same confirmation card a chat-driven write
    produces, so a UI shortcut never bypasses the write guard."""
    o = (_state.get("ops", {}) or {}).get(oid)
    if not o:
        return JSONResponse({"error": f"operation {oid} not in the API spec"}, status_code=404)
    m = _PATH_PARAM_RE.search(o.get("path", ""))
    pname = m.group(0)[1:-1] if m else "node_id"
    res = invoke(oid, path_params={pname: mac}, body=body or None)
    if isinstance(res, dict) and res.get("confirmation_required"):
        res["summary"] = summary
        return JSONResponse({"confirm": res})
    return JSONResponse({"error": "unexpected response preparing the change",
                         "result": res}, status_code=500)


def _find_node(mac: str) -> dict:
    """Look up a node by MAC via the PF API. Tries the known node-view operation
    ids, then any GET on /node/{...} or /nodes/{...} discovered in the spec, so
    it works across PacketFence versions and path spellings."""
    tried: list[str] = []
    last_status = None
    for oid in _node_view_ops():
        o = _state.get("ops", {}).get(oid)
        if not o:
            continue
        # take the parameter name from the PATH itself, so the value can never
        # land in the wrong slot when a spec declares several path params
        m = _PATH_PARAM_RE.search(o.get("path", ""))
        pname = m.group(0)[1:-1] if m else "node_id"
        res = invoke(oid, path_params={pname: mac})
        tried.append(oid)
        if isinstance(res, dict):
            last_status = res.get("status_code")
            if last_status == 200:
                body = res.get("body")
                # PF wraps the record as {"item": {...}} on some endpoints
                if isinstance(body, dict) and "item" in body and isinstance(body["item"], dict):
                    body = body["item"]
                return {"operation_id": oid, "node": body}
    if not tried:
        return {"error": "no single-node GET operation found in the OpenAPI spec "
                         "(looked for /node/{id} and /nodes/{id})"}
    return {"error": f"node {mac} not found via the API "
                     f"(tried {', '.join(tried[:4])}; last HTTP {last_status})",
            "tried": tried}


def diagnose(mac: str = "", username: str = "") -> dict:
    """End-to-end triage for a device/user: gather the node record (if MAC) and
    recent log evidence, and return it structured for the agent to interpret.
    Does NOT change anything — read-only."""
    mac = (mac or "").strip()
    username = (username or "").strip()
    if not mac and not username:
        return {"error": "a MAC address or username is required to diagnose"}

    report: dict = {"subject": {"mac": mac or None, "username": username or None},
                    "steps": []}

    # 1. node lookup (MAC only)
    if mac:
        if not _MAC_RE.match(mac):
            return {"error": "a valid MAC address is required (e.g. aa:bb:cc:dd:ee:ff)"}
        node = _find_node(mac)
        report["node"] = node
        report["steps"].append("node_lookup:" + ("ok" if "node" in node else "not_found"))

    # 2. logs (radius first — that's where auth results live)
    logs = search_logs(mac=mac, username=username, which="both", limit=150) if (mac or username) else {}
    report["logs"] = logs.get("logs", {})
    rc = sum(v.get("match_count", 0) for v in report["logs"].values() if isinstance(v, dict))
    report["steps"].append(f"log_search:{rc}_lines")

    # 3. determine the verdict from the LAST radius line. PacketFence's FreeRADIUS
    #    logs "Login OK" (accept) or "Login incorrect (<reason>)" (reject).
    radius = (report["logs"].get("radius") or {}).get("lines", [])
    verdict = None          # "Access-Accept" | "Access-Reject" | None
    verdict_line = None
    reject_reason = None
    for ln in reversed(radius):
        low = ln.lower()
        if "login ok" in low or "access-accept" in low:
            verdict, verdict_line = "Access-Accept", ln.strip(); break
        if "login incorrect" in low or "access-reject" in low:
            verdict, verdict_line = "Access-Reject", ln.strip()
            # the reason is in the first parentheses: "Login incorrect (<reason>): [user]"
            m = re.search(r"Login incorrect\s*\(([^)]+)\)", ln, re.I)
            if m:
                reject_reason = m.group(1).strip()
            break
    report["last_radius_result"] = verdict_line
    report["verdict"] = verdict
    if reject_reason:
        report["reject_reason"] = reject_reason
    report["steps"].append("radius_verdict:" + (verdict or "none"))

    # the packetfence.log block for the LATEST attempt (starts at "handling
    # radius autz request", runs to the "returned RADIUS Access-*" line).
    latest_block = _latest_autz_block(
        (report["logs"].get("packetfence") or {}).get("lines", []))
    def _ln_ts(s):
        m3 = re.match(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.\d]*)", s.strip())
        return m3.group(1) if m3 else ""
    _rad_latest = ""
    for _ln in (report["logs"].get("radius") or {}).get("lines", []):
        _t = _ln_ts(_ln)
        if _t > _rad_latest:
            _rad_latest = _t
    def _stale_block(block):
        # True when the autz trail predates the newest radius verdict line —
        # i.e. we grepped the file before the pipeline flushed this attempt.
        if not block or not _rad_latest:
            return False
        _bt = ""
        for _ln in block:
            _t = _ln_ts(_ln)
            if _t > _bt:
                _bt = _t
        return bool(_bt) and _bt < _rad_latest
    if (not latest_block) or _stale_block(latest_block):
        # A username search mostly matches admin-API (httpd.aaa) noise — including
        # this assistant's own calls — while the RADIUS policy trail is keyed by
        # MAC. Pull a MAC from the radius verdict lines and re-grep by it.
        fb_mac = mac or None
        if not fb_mac:
            for ln in reversed((report["logs"].get("radius") or {}).get("lines", [])):
                m2 = re.search(r"[0-9A-Fa-f]{2}(?:[:\-][0-9A-Fa-f]{2}){5}", ln)
                if m2:
                    fb_mac = m2.group(0)
                    break
        if fb_mac:
            for _attempt in range(3):
                pf2 = search_logs(mac=fb_mac, which="packetfence", limit=200)
                grp = (pf2.get("logs") or {}).get("packetfence")
                blk = _latest_autz_block(grp.get("lines") or []) if isinstance(grp, dict) else []
                if blk and not _stale_block(blk):
                    latest_block = blk
                    report["logs"]["packetfence"] = grp
                    report["steps"].append(f"autz_refetch_by_mac:{fb_mac} (attempt {_attempt + 1})")
                    break
                if _attempt == 2 and blk:
                    # out of retries: a slightly stale trail beats an empty verdict
                    latest_block = blk
                    report["logs"]["packetfence"] = grp
                    report["steps"].append(f"autz_refetch_by_mac:{fb_mac} (stale after retries)")
                    break
                if _attempt < 2:
                    time.sleep(2.5)
                    report["steps"].append("autz_wait_for_log_flush:2.5s")
    if latest_block:
        report["latest_attempt_pf"] = latest_block
        report["returned_attributes"] = _attrs_from_autz_block(latest_block)

    # ── preformatted recent-log block for verbatim display ───────────────────
    # radius: last few verdict lines; packetfence: the latest attempt's block.
    report["recent_log_block"] = _format_diagnose_logs(
        report["logs"], latest_block)

    report["_guidance"] = (
        "Produce the diagnosis in EXACTLY this format and order. Use markdown '###' "
        "headings. Do not add, rename, reorder, or drop sections. Keep wording tight.\n\n"
        "### Recent log entries\n"
        "<the lines from 'recent_log_block' verbatim, in a fenced code block>\n\n"
        "### Verdict\n"
        "<ONE plain-sentence summary of the outcome, NOT bold, mentioning the VLAN id "
        "when there is one — e.g. 'Authentication succeeded - device placed in the "
        "registration VLAN 2.' or 'Authentication failed - wrong credentials.'>\n\n"
        "- Result: <Access-Accept or Access-Reject from 'verdict'; if rejected append "
        "the reason from 'reject_reason'>\n"
        "- Role: <returned_attributes.role>\n"
        "- VLAN: <returned_attributes.vlan>\n"
        "- Node status: <returned_attributes.status, written as registered/unregistered>\n\n"
        "### Details\n"
        "- MAC / username: <returned_attributes.mac> / <returned_attributes.username>\n"
        "- Connection type: <returned_attributes.connection_type>\n"
        "- Switch IP: <returned_attributes.switch_ip>\n"
        "- Connection profile: <returned_attributes.profile>\n"
        "- Authentication source: <returned_attributes.auth_source>\n\n"
        "### Overall analysis\n"
        "<2-3 sentences: whether the device is registered, what the result means, and "
        "the single most likely fix.>\n\n"
        "RULES: For any field whose value is missing or empty, write exactly 'NA' (never "
        "omit the line, never invent a value). Show MACs, IPs, VLAN ids, and usernames "
        "in backticks in the bullet lists. The one-line summary and Overall analysis are "
        "plain prose (no bold). Base Verdict and Details ONLY on the latest attempt."
    )

    # ── resolve a MAC for actions ────────────────────────────────────────────
    # For a MAC diagnose, that's the MAC. For a username diagnose, try to pull a
    # MAC out of the matched log lines so actions can target the device.
    action_mac = mac or None
    if not action_mac and username:
        for grp in report["logs"].values():
            if not isinstance(grp, dict):
                continue
            for ln in grp.get("lines", []):
                mm = _MAC_RE.search(ln) if hasattr(_MAC_RE, "search") else None
                m2 = re.search(r"[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}", ln)
                if m2:
                    action_mac = m2.group(0)
                    break
            if action_mac:
                break

    # ── registration status → drives Register vs Deregister ──────────────────
    status = None
    nb = (report.get("node") or {}).get("node") if isinstance(report.get("node"), dict) else None
    if isinstance(nb, dict):
        # PF exposes status as "reg"/"unreg" (sometimes "status")
        raw = str(nb.get("status", "")).lower()
        if raw in ("reg", "registered"):
            status = "registered"
        elif raw in ("unreg", "unregistered"):
            status = "unregistered"
    # if we only have a username-resolved MAC with no node body, status stays None
    # and the UI will offer both-safe actions (Reevaluate) plus a neutral toggle.

    if action_mac:
        report["node_actions"] = _node_panel(
            action_mac, status,
            nb if isinstance(nb, dict) else None,
            report.get("returned_attributes") if isinstance(report.get("returned_attributes"), dict) else None)

    return report




TOOL_RESULT_MAX = int(os.environ.get("TOOL_RESULT_MAX", "12000"))


def _cap_result(name: str, result):
    """Keep a tool result inside a sane token budget.

    Every iteration of the agent loop re-sends the whole conversation, so one
    oversized result is paid for again on each subsequent step. Trimming a long
    list is far better than truncating its JSON mid-string, which would leave the
    model parsing garbage."""
    try:
        raw = json.dumps(result, default=str)
    except Exception:
        return result
    if len(raw) <= TOOL_RESULT_MAX:
        return result
    if isinstance(result, dict):
        body = result.get("body")
        for holder, key in ((result, "items"), (body if isinstance(body, dict) else {}, "items")):
            items = holder.get(key) if isinstance(holder, dict) else None
            if isinstance(items, list) and len(items) > 1:
                keep = max(1, len(items) * TOOL_RESULT_MAX // max(len(raw), 1))
                holder[key] = items[:keep]
                holder["_truncated"] = (
                    f"showing {keep} of {len(items)} items to stay within the token "
                    f"budget; narrow the query (filters, fields, limit) for more")
                return result
    return {"_truncated": f"{name} returned {len(raw)} chars, truncated",
            "preview": raw[:TOOL_RESULT_MAX]}


def dispatch(name: str, a: dict) -> dict:
    if name == "pf_search_operations":
        return {"operations": search_ops(a.get("query", ""), a.get("limit", 12))}
    if name == "pf_describe_operation":
        return describe(a.get("operation_id", ""))
    if name == "pf_call_operation":
        return invoke(a.get("operation_id", ""), a.get("path_params"), a.get("query_params"), a.get("body"))
    if name == "pf_search_docs":
        return {"results": search_docs(a.get("query", ""), a.get("limit", 6))}
    if name == "pf_search_logs":
        return search_logs(a.get("mac", ""), a.get("which", "both"), a.get("limit", 80),
                           a.get("username", ""))
    if name == "pf_diagnose":
        return diagnose(a.get("mac", ""), a.get("username", ""))
    if name == "pf_run_test":
        return prepare_test(a.get("tool", ""), a.get("username", ""),
                            a.get("password", ""), a.get("nas_ip", ""))
    if name == "pf_roles":
        return list_roles(a.get("name", ""))
    if name == "pf_describe_fields":
        return options_meta(a.get("target", ""))
    if name == "pf_node_details":
        return node_details(a.get("mac", ""))
    if name == "pf_write_file":
        return write_file(a.get("name", ""), a.get("content", ""), a.get("mime", ""))
    if name == "pf_list_files":
        return list_thread_files()
    if name == "pf_read_file":
        return read_thread_file(a.get("file_id"), a.get("name", ""),
                                a.get("offset", 0), a.get("length", 0))
    if name == "pf_capture":
        return prepare_capture(a.get("preset", ""), a.get("filter", ""),
                               a.get("seconds"), a.get("packets"), a.get("iface", ""))
    return {"error": f"unknown tool {name}"}


# (source key, label) in display order. The node record and the attributes a
# diagnose parses out of the RADIUS log are both searched; the first non-empty
# value wins. Anything absent is simply not emitted, so the inspector never
# shows a blank row.
_NP_FIELDS = (
    ("status",               "Status"),
    ("category",             "Role"),
    ("role",                 "Role"),
    ("bypass_role",          "Bypass role"),
    ("bypass_vlan",          "Bypass VLAN"),
    ("pid",                  "Owner / PID"),
    ("computername",         "Hostname"),
    ("device_type",          "Device type"),
    ("device_class",         "Device class"),
    ("device_manufacturer",  "Manufacturer"),
    ("machine_account",      "Machine account"),
    ("voip",                 "VoIP"),
    ("autoreg",              "Auto-registered"),
    ("regdate",              "Registered"),
    ("unregdate",            "Unregisters"),
    ("last_seen",            "Last seen"),
    ("detect_date",          "First detected"),
    ("last_role",            "Last role"),
    ("last_connection_type", "Last connection"),
    ("connection_type",      "Last connection"),
    ("last_vlan",            "Last VLAN"),
    ("vlan",                 "Last VLAN"),
    ("last_switch",          "Last switch"),
    ("switch_ip",            "Last switch"),
    ("last_port",            "Last port"),
    ("last_ssid",            "Last SSID"),
    ("last_ip",              "Last IP"),
    ("ip",                   "Last IP"),
    ("last_dot1x_username",  "Last 802.1X user"),
    ("dhcp_fingerprint",     "DHCP fingerprint"),
    ("user_agent",           "User agent"),
    ("profile",              "Connection profile"),
    ("notes",                "Notes"),
)
# values that mean "nothing here" in PacketFence
_NP_EMPTY = {"", "none", "na", "n/a", "null", "0000-00-00 00:00:00", "0000-00-00", "unknown"}


def _np_clean(v):
    if v is None or isinstance(v, (dict, list)):
        return None
    s = str(v).strip()
    return None if s.lower() in _NP_EMPTY else s


def _node_panel(mac: str, status=None, node: dict | None = None,
                attrs: dict | None = None) -> dict:
    """Everything the node inspector shows.

    Emits an ordered `facts` list of {label, value} so the UI renders exactly
    what the backend found — no second field list to drift out of step — plus
    `status` and `role` as discrete keys, which drive the action buttons and
    preselect the role picker."""
    node = node if isinstance(node, dict) else {}
    attrs = attrs if isinstance(attrs, dict) else {}
    merged = {**attrs, **{k: v for k, v in node.items() if _np_clean(v) is not None}}
    if status:
        merged["status"] = status

    facts, seen_labels, out = [], set(), {"mac": mac, "status": status}
    for key, label in _NP_FIELDS:
        if label in seen_labels:
            continue
        v = _np_clean(merged.get(key))
        if v is None:
            continue
        seen_labels.add(label)
        facts.append({"label": label, "value": v})
        if label == "Role" and "role" not in out:
            out["role"] = v
    out["facts"] = facts
    return out


def node_details(mac: str) -> dict:
    """One node's record. Uses the same resolver as pf_diagnose, which tries the
    known node-view operation ids and then discovers any GET .../nodes/{...},
    so it works across PF versions without a semantic search."""
    mac = (mac or "").strip()
    if not mac:
        return {"error": "a MAC address is required"}
    if not _MAC_RE.match(mac):
        return {"error": f"{mac!r} is not a valid MAC address (e.g. aa:bb:cc:dd:ee:ff)"}
    res = _find_node(mac)
    if "node" not in res:
        return {"error": res.get("error", "node not found"), "mac": mac}
    body = res["node"]
    if isinstance(body, dict) and "item" in body:
        body = body["item"]
    return {"mac": mac, "operation_id": res.get("operation_id"), "node": body,
            "node_actions": _node_panel(
                mac,
                {"reg": "registered", "unreg": "unregistered"}.get(
                    str((body or {}).get("status", "")).lower()),
                body if isinstance(body, dict) else None),
            "_guidance": "Present the returned fields plainly (status, registration, "
                         "owner/pid, device type, last seen, roles, notes). Do not run a "
                         "diagnosis or search logs unless the user asks."}


_READ_SLICE_MAX = 40000


def write_file(name: str, content: str, mime: str = "") -> dict:
    """Agent-produced artifact, saved against the current user + thread."""
    pid, tid = _cur_pid.get(), _cur_tid.get()
    if not pid or not tid:
        return {"error": "no conversation context; cannot save a file"}
    if not (name or "").strip():
        return {"error": "a filename is required"}
    data = (content or "").encode("utf-8")
    if not mime:
        import mimetypes
        mime = mimetypes.guess_type(name)[0] or "text/plain"
    try:
        f = store.add_file(pid, tid, name, data, mime, kind="output")
    except store.FileTooLarge as e:
        return {"error": f"file too large: {e}"}
    except store.QuotaExceeded as e:
        return {"error": str(e)}
    except Exception as e:
        return {"error": f"could not save file: {e}"}
    produced = _produced_files.get()
    if produced is None:
        produced = []
        _produced_files.set(produced)
    produced.append(f)
    return {"saved": True, **f,
            "note": "The user can download this from the link under your reply. "
                    "Mention the filename; do not paste the whole content again."}


def list_thread_files() -> dict:
    pid, tid = _cur_pid.get(), _cur_tid.get()
    if not pid or not tid:
        return {"files": []}
    try:
        return {"files": store.list_files(pid, tid)}
    except Exception as e:
        return {"error": str(e)}


def read_thread_file(file_id=None, name: str = "", offset: int = 0, length: int = 0) -> dict:
    """Read an attachment in bounded slices — uploads are not RAG-indexed, so this
    is how the agent sees them, and slicing keeps a big log out of the context."""
    pid, tid = _cur_pid.get(), _cur_tid.get()
    if not pid or not tid:
        return {"error": "no conversation context"}
    try:
        if not file_id and name:
            for f in store.list_files(pid, tid):
                if f["name"].lower() == name.strip().lower():
                    file_id = f["id"]
                    break
        if not file_id:
            return {"error": "file not found; call pf_list_files first"}
        rec = store.get_file(pid, int(file_id))
    except Exception as e:
        return {"error": str(e)}
    if not rec or rec.get("thread_id") != tid:
        return {"error": "file not found in this conversation"}
    if rec.get("data") is None:
        return {"error": rec.get("error", "file content unavailable")}
    data = rec["data"]
    offset = max(0, int(offset or 0))
    length = int(length or _READ_SLICE_MAX)
    length = max(1, min(length, _READ_SLICE_MAX))
    chunk = data[offset:offset + length]
    try:
        text = chunk.decode("utf-8")
    except UnicodeDecodeError:
        return {"error": "this file is not UTF-8 text and cannot be read as text",
                "name": rec["name"], "size_bytes": rec["size_bytes"]}
    end = offset + len(chunk)
    return {"name": rec["name"], "mime": rec["mime"], "size_bytes": rec["size_bytes"],
            "offset": offset, "returned": len(chunk), "eof": end >= rec["size_bytes"],
            "next_offset": None if end >= rec["size_bytes"] else end,
            "content": text}


def prepare_capture(preset: str = "", flt: str = "", seconds=None, packets=None, iface: str = "") -> dict:
    """Build a 'prepared capture' the UI opens in the capture panel for the user
    to review and run. Does NOT capture here."""
    preset = (preset or "").strip() or "radius"
    fields = {
        "preset": preset,
        "filter": (flt or "").strip(),
        "seconds": int(seconds) if seconds else 20,
        "packets": int(packets) if packets else 200,
    }
    if (iface or "").strip():
        fields["iface"] = iface.strip()
    return {"prepare_capture": fields}


def prepare_test(tool: str, username: str, password: str = "", nas_ip: str = "") -> dict:
    """Build a 'prepared test' the UI opens+fills in the Test Tools panel for the
    user to review and run. Does NOT execute anything here."""
    tool = (tool or "").strip()
    username = (username or "").strip()
    if tool not in ("eapol_test", "radclient"):
        return {"error": "tool must be eapol_test or radclient"}
    if not username:
        return {"error": "a username (or MAC for radclient) is required"}

    if tool == "eapol_test":
        variant = "PEAP"
        fields = {"username": username, "password": password or "",
                  "secret": "", "timeout": "20"}
    else:  # radclient MAB — MAC used as both username and password
        mac_bare = re.sub(r"[^0-9A-Fa-f]", "", username).lower()
        variant = "PAP"
        fields = {
            "username": mac_bare or username,
            "password": password or mac_bare or username,
            "nas_ip": nas_ip or "192.168.0.1",
            "calling_station": ":".join(mac_bare[i:i+2] for i in range(0, 12, 2)) if len(mac_bare) == 12 else "",
            "called_station": "",
            "timeout": "20",
        }
    return {"prepare_test": {"tool": tool, "variant": variant, "fields": fields}}


# Per-request collector for a write awaiting confirmation. run_agent resets it;
# dispatch records into it; the chat endpoint reads it to surface the dialog.
_pending_confirm = contextvars.ContextVar("pending_confirm", default=None)
_node_actions = contextvars.ContextVar("node_actions", default=None)
_prepare_test = contextvars.ContextVar("prepare_test", default=None)
_prepare_capture = contextvars.ContextVar("prepare_capture", default=None)
# current user/thread, so file tools know where to read and write
_cur_pid = contextvars.ContextVar("cur_pid", default=None)
_cur_tid = contextvars.ContextVar("cur_tid", default=None)
_produced_files = contextvars.ContextVar("produced_files", default=None)
# "confirm ... dialog/below my message" — the sentence the prompt teaches, which
# the model sometimes emits without having called pf_call_operation at all
_PROMISED_CONFIRM_RE = re.compile(
    r"confirm[^.\n]{0,80}?(dialog|below (?:my|this) message|prompt below)"
    r"|(dialog|below (?:my|this) message)[^.\n]{0,80}?confirm", re.I)
_run_id = contextvars.ContextVar("run_id", default=None)
_can_write = contextvars.ContextVar("can_write", default=True)


class RunCancelled(Exception):
    """Raised out of the tool dispatcher when the caller asked to stop."""


# Cooperative cancellation. The agent loop calls dispatch between model turns,
# so raising there stops the run BEFORE the next (expensive) completion — which
# is where a runaway 8-iteration query actually spends its tokens. The
# completion already in flight still finishes; nothing can abort that mid-call.
_runs_lock = threading.Lock()
_active_runs: dict[str, str] = {}      # run_id -> pid
_cancel_requests: dict[str, float] = {}  # run_id -> when it was asked to stop
_CANCEL_KEEP = 256


def _run_begin(run_id: str, pid: str) -> None:
    if not run_id:
        return
    with _runs_lock:
        _active_runs[run_id] = pid


def _run_end(run_id: str) -> None:
    if not run_id:
        return
    with _runs_lock:
        _active_runs.pop(run_id, None)
        _cancel_requests.pop(run_id, None)


def _run_cancel(run_id: str, pid: str) -> dict:
    """Ask a run to stop. Scoped to its owner so one user cannot cancel another's."""
    if not run_id:
        return {"error": "run_id required"}
    with _runs_lock:
        owner = _active_runs.get(run_id)
        if owner is not None and owner != pid:
            return {"error": "not your run"}
        _cancel_requests[run_id] = time.time()
        if len(_cancel_requests) > _CANCEL_KEEP:      # keep the map bounded
            for k in sorted(_cancel_requests, key=_cancel_requests.get)[:64]:
                _cancel_requests.pop(k, None)
        return {"ok": True, "known": owner is not None}


def _run_is_cancelled(run_id: str) -> bool:
    if not run_id:
        return False
    with _runs_lock:
        return run_id in _cancel_requests


def dispatch_guarded(name: str, a: dict) -> dict:
    """Wrap dispatch so a confirmation_required result is captured for the UI,
    and cap the result so one oversized payload cannot exhaust the token budget.

    Also the cancellation checkpoint: the agent loop calls this between model
    turns, so raising here ends the run before the next completion is paid for."""
    if _run_is_cancelled(_run_id.get()):
        raise RunCancelled()
    res = _cap_result(name, dispatch(name, a))
    if isinstance(res, dict) and res.get("confirmation_required"):
        _pending_confirm.set({
            "confirm_token": res["confirm_token"],
            "operation_id": res["operation_id"],
            "method": res["method"],
            "path": res["path"],
            "summary": res.get("summary", ""),
        })
    if isinstance(res, dict) and res.get("node_actions"):
        _node_actions.set(res["node_actions"])
    if isinstance(res, dict) and res.get("prepare_test"):
        _prepare_test.set(res["prepare_test"])
    if isinstance(res, dict) and res.get("prepare_capture"):
        _prepare_capture.set(res["prepare_capture"])
    return res






# ── agent loop (provider-agnostic) ───────────────────────────────────────────
HISTORY_CHAR_BUDGET = int(os.environ.get("HISTORY_CHAR_BUDGET", "24000"))


def _window_history(msgs: list[dict]) -> list[dict]:
    """Send the most recent slice of the thread, not all of it.

    The agent loop re-sends the entire conversation on every iteration, so an
    old long thread is paid for repeatedly and eventually trips the provider's
    per-minute token limit. Keeps the newest messages within a character budget
    (~4 chars/token) and drops a leading assistant turn so the slice still starts
    on a user message."""
    kept: list[dict] = []
    used = 0
    for m in reversed(msgs):
        c = len(m.get("content") or "")
        if kept and used + c > HISTORY_CHAR_BUDGET:
            break
        kept.append(m)
        used += c
    kept.reverse()
    while kept and kept[0].get("role") != "user":
        kept.pop(0)
    return kept




def _version_addendum() -> str:
    """The running version as prompt text. Thin wrapper over prompts.version_line
    so the wording lives with the rest of the prompt, not the application logic."""
    return version_line(_state.get("pf_version") or "")


def _preferred_style_addendum(pid: str | None, thread_id: str | None,
                              max_examples: int = 3) -> str:
    """Fetch this user's thumbs-up replies and hand them to the prompt builder."""
    if not pid:
        return ""
    try:
        rows = store.liked_examples(pid, thread_id, max_examples)
    except Exception:
        return ""
    return style_addendum(list(rows), max_examples)


def run_agent(history: list[dict], debug: bool = False,
              thread_id: str | None = None, pid: str | None = None) -> tuple[str, list[str], dict]:
    if not _state.get("ready"):
        return (
            "Still starting up — indexing the API spec and documentation. "
            "This takes a moment on first boot; try again shortly.",
            [], {},
        )
    prov = _state.get("provider")
    if prov is None:
        return (
            "No provider configured — set PROVIDER and API_KEY in .env, or use the gear icon "
            "in the UI to pick a provider and enter a key.",
            [], {},
        )
    _pending_confirm.set(None)
    _node_actions.set(None)
    _prepare_test.set(None)
    _prepare_capture.set(None)
    _cur_pid.set(pid)
    _cur_tid.set(thread_id)
    _produced_files.set([])
    system = (SYSTEM + _version_addendum() + read_only_line(_can_write.get())
              + _preferred_style_addendum(pid, thread_id))
    if not debug:
        return prov.run_agent(system, history, TOOLS, dispatch_guarded, label, max_iters=8)

    # Debug mode: two collectors record everything the agent does —
    #   1. dbg_dispatch wraps the tool dispatcher (tool name, args, timing, size)
    #   2. HTTP hooks on the shared client record every outbound API request
    #      (LLM completions AND PacketFence calls) with status/size/latency.
    # Events carry timestamps and are merged chronologically, so the trace
    # reads as the true sequence of what happened.
    t_start = time.time()
    events: list[tuple[float, str]] = []

    def dbg_dispatch(name: str, args: dict):
        t0 = time.time()
        try:
            result = dispatch_guarded(name, args)
        except Exception as e:
            events.append((time.time(), f"\u00b7 tool {name} raised after {time.time()-t0:.2f}s: {e}"))
            raise
        try:
            size = len(json.dumps(result, default=str))
        except (TypeError, ValueError):
            size = -1
        arg_s = json.dumps(args, default=str)
        if len(arg_s) > 200:
            arg_s = arg_s[:200] + "\u2026"
        events.append(
            (time.time(), f"\u00b7 tool {name} args={arg_s} \u2192 {size}B in {time.time()-t0:.2f}s")
        )
        # if the tool made a PacketFence API call, surface the equivalent curl
        curl = result.get("curl") if isinstance(result, dict) else None
        if curl:
            sc = result.get("status_code")
            events.append((time.time(), f"\u00b7 curl [{sc}]:: {curl}"))
        return result

    token = _dbg_events.set(events)
    try:
        reply, activity, usage = prov.run_agent(system, history, TOOLS, dbg_dispatch, label, max_iters=8)
    finally:
        _dbg_events.reset(token)

    dbg_lines = [line for _, line in sorted(events, key=lambda e: e[0])]
    n_tools = sum(1 for l in dbg_lines if l.startswith("\u00b7 tool "))
    n_http = sum(1 for l in dbg_lines if l.startswith("\u00b7 http "))
    dbg_lines.append(
        f"\u00b7 total: {n_tools} tool call(s), {n_http} http request(s), "
        f"provider={_state.get('cfg', {}).get('provider','?')}, "
        f"model={getattr(prov, 'model', '?')}, {time.time()-t_start:.2f}s end-to-end"
    )
    return reply, list(activity) + dbg_lines, usage



# ── conversation storage (MySQL, per PacketFence person) ────────────────────
# History lives in PacketFence's own database keyed by person.pid, so each admin
# sees only their own threads and a deleted person takes their history with them.
import store

CHATBOT_USER_HEADER = os.environ.get("CHATBOT_USER_HEADER", "X-PF-Username")
# PacketFence's AAA layer sets X-PacketFence-Username on the proxied request
# (go/api-frontend/aaa/authorization.go), so behind the admin API set
# CHATBOT_USER_HEADER=X-PacketFence-Username.
# The admin proxy also passes the caller's admin actions. A user who lacks the
# write action may ask anything but may not stage or run a change.
CHATBOT_ROLES_HEADER = os.environ.get("CHATBOT_ROLES_HEADER", "X-PF-Admin-Actions")
CHATBOT_WRITE_ACTION = os.environ.get("CHATBOT_WRITE_ACTION", "CHATBOT_WRITE")
# The proxy forwards the caller's admin ROLE NAMES (X-PacketFence-Admin-Roles,
# set in go/api-frontend/aaa/authorization.go), not expanded actions. Accept the
# integration's write-capable role plus the superuser roles; override the list
# with CHATBOT_WRITE_GRANTS=name1,name2 if a deployment defines its own roles.
_WRITE_GRANTS = {g.strip().upper() for g in os.environ.get(
    "CHATBOT_WRITE_GRANTS",
    CHATBOT_WRITE_ACTION + ",CHATBOT-ADMIN,ALL,ALL_PF_ONLY").split(",") if g.strip()}
# Open by default so a standalone install keeps working; the PacketFence
# integration sets this to 1 so an unproxied request can never write.
CHATBOT_REQUIRE_WRITE_ACTION = os.environ.get("CHATBOT_REQUIRE_WRITE_ACTION", "0") == "1"


def admin_actions(request) -> set:
    """Admin actions the proxy says this caller holds, upper-cased."""
    try:
        raw = request.headers.get(CHATBOT_ROLES_HEADER) or ""
    except Exception:
        raw = ""
    return {a.strip().upper() for a in re.split(r"[,\s]+", raw) if a.strip()}


def may_write(request) -> bool:
    """Whether this caller is allowed to change anything.

    With CHATBOT_REQUIRE_WRITE_ACTION off (standalone), everyone may write and
    the confirmation dialog is the only gate. Behind PacketFence it is on, so a
    chatbot-user (read-only) role can use the assistant but cannot alter a node."""
    if not CHATBOT_REQUIRE_WRITE_ACTION:
        return True
    acts = admin_actions(request)
    return bool(acts & _WRITE_GRANTS)


def deny_write():
    return JSONResponse(
        {"error": "your admin role grants read-only access to the assistant; "
                  "ask an administrator with the write action to make this change"},
        status_code=403)


def current_pid(request) -> str:
    """Resolve the PacketFence person for this request.

    The username is taken from a trusted header set by whatever fronts this
    service (the PacketFence admin proxy / SSO). With nothing in front, every
    caller resolves to CHATBOT_DEFAULT_PID — separation is only as strong as
    the thing setting the header, so do not expose the port directly."""
    pid = ""
    try:
        pid = (request.headers.get(CHATBOT_USER_HEADER)
               or request.headers.get("X-PacketFence-Username")
               or request.headers.get("X-Forwarded-User") or "").strip()
    except Exception:
        pid = ""
    return store.resolve_pid(pid)


# Mutating endpoints live under /write/ so PacketFence's AAA layer can pin the
# required action by PATH rather than by HTTP method. Asking a question is a
# POST that must only need CHATBOT_READ; the method map would make it _CREATE.
#
# ── web app ──────────────────────────────────────────────────────────────────
app = FastAPI()


@app.on_event("startup")
def _startup():
    # Initialize in a background thread so uvicorn starts listening immediately;
    # the UI loads right away and /chat reports "warming up" until ready.
    threading.Thread(target=_init, daemon=True).start()


def _init():
    try:
        print(f"[pf-bot] indexed {load_spec()} operations")
    except Exception as e:
        print(f"[pf-bot] could not load spec yet: {e}")
    try:
        build_rag()
    except Exception as e:
        print(f"[pf-bot] RAG build failed: {e}")
    try:
        store.init()
        print(f"[pf-bot] conversation store ready: {store.status()}")
    except Exception as e:
        print(f"[pf-bot] conversation store UNAVAILABLE: {e}")
    cfg = _effective_config()
    if not cfg["provider"] or not cfg["api_key"]:
        print("[pf-bot] PROVIDER and API_KEY are required; set them in .env or via the UI settings (gear icon).")
        _state["ready"] = True
        return
    try:
        _apply_provider(cfg)
    except Exception as e:
        print(f"[pf-bot] provider init failed: {e}")
    _state["pf_version"] = _detect_pf_version()
    print(f"[pf-bot] PacketFence version: {_state['pf_version'] or 'unknown'}")
    _state["ready"] = True
    threading.Thread(target=_file_housekeeping, daemon=True).start()
    print("[pf-bot] startup complete")


def _file_housekeeping():
    """Expire old uploads and reclaim blobs no row references any more.
    The database is authoritative, so this is safe to run at any time."""
    while True:
        try:
            n = store.purge_expired_uploads()
            orphans = store.purge_orphans()   # in case the person FK is absent
            sw = store.sweep_orphans()
            if n or sw["removed"] or orphans:
                print(f"[pf-bot] housekeeping: expired {n} upload(s); reclaimed "
                      f"{sw['removed']} orphan blob(s), {sw['bytes']}B; purged "
                      f"{orphans} row(s) for deleted persons")
        except Exception as e:
            print(f"[pf-bot] file housekeeping skipped: {e}")
        time.sleep(24 * 3600)


@app.get("/threads")
def list_threads(request: Request):
    return JSONResponse(store.list_threads(current_pid(request)))


@app.post("/feedback")
def set_feedback(payload: dict, request: Request):
    """Record thumbs up/down on an assistant message.
    rating: 1 = good, -1 = not good, 0 = cleared."""
    mid = payload.get("message_id")
    rating = payload.get("rating")
    if mid is None or rating not in (1, -1, 0):
        return JSONResponse({"error": "message_id and rating (1|-1|0) required"}, status_code=400)
    res = store.set_feedback(current_pid(request), int(mid), int(rating))
    return JSONResponse(res, status_code=400 if res.get("error") else 200)


@app.get("/threads/search")
def search_threads(request: Request, q: str = ""):
    """Search this user's threads by title AND message body. Backed by the MySQL
    FULLTEXT indexes, with a substring fallback for very short queries."""
    return JSONResponse(store.search_threads(current_pid(request), q))


@app.get("/usage")
def get_usage(request: Request):
    """Daily (last 30 days) and monthly (last 12 months) token usage, per user."""
    return JSONResponse(store.usage(current_pid(request)))


@app.get("/threads/{tid}")
def get_thread(tid: str, request: Request):
    pid = current_pid(request)
    t = store.get_thread(pid, tid)
    if t is None:
        return JSONResponse({"error": "thread not found"}, status_code=404)
    # attachments so the UI can re-render download links under the right reply
    t["files"] = store.list_files(pid, tid)
    return JSONResponse(t)


@app.delete("/threads/{tid}")
def delete_thread(tid: str, request: Request):
    store.delete_thread(current_pid(request), tid)
    return JSONResponse({"ok": True})


import socket as _socket


def _testtool_call(payload: dict, timeout: float = 40.0) -> dict:
    """Talk to the host helper over its Unix socket. The container never runs
    the test binaries itself; this is a thin, validated RPC."""
    try:
        s = _socket.socket(_socket.AF_UNIX, _socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(TESTTOOL_SOCK)
    except OSError as e:
        return {"ok": False, "error": f"test helper not reachable ({e}). Is pf-testtool-helper "
                                      "running on the host and the socket mounted into the container?"}
    try:
        s.sendall((json.dumps(payload) + "\n").encode())
        buf = b""
        while b"\n" not in buf:
            chunk = s.recv(8192)
            if not chunk:
                break
            buf += chunk
        return json.loads(buf.split(b"\n", 1)[0].decode()) if buf else {"ok": False, "error": "empty response"}
    except Exception as e:
        return {"ok": False, "error": f"helper communication error: {e}"}
    finally:
        s.close()


TESTTOOLS_META = {
    "eapol_test": {
        "label": "eapol_test (802.1X / EAP)",
        "desc": "Full 802.1X supplicant handshake against PacketFence RADIUS.",
        "variants": {
            "PEAP": {
                "label": "PEAP / MSCHAPv2",
                "fields": [
                    {"name": "secret", "label": "RADIUS secret (Empty for default)", "type": "password", "default": ""},
                    {"name": "username", "label": "Username", "type": "text", "default": "testuser"},
                    {"name": "password", "label": "Password", "type": "password", "default": ""},
                    {"name": "timeout", "label": "Timeout (seconds)", "type": "text", "default": "20"},
                ],
            },
            "TLS": {
                "label": "EAP-TLS (certificates)",
                "fields": [
                    {"name": "username", "label": "Identity", "type": "text", "default": "host/testpc"},
                    {"name": "client_cert", "label": "Client cert (host path)", "type": "text", "default": "/usr/local/pf/conf/ssl/client.crt"},
                    {"name": "private_key", "label": "Private key (host path)", "type": "text", "default": "/usr/local/pf/conf/ssl/client.key"},
                    {"name": "ca_cert", "label": "CA cert (optional)", "type": "text", "default": "/usr/local/pf/conf/ssl/cacert.pem"},
                    {"name": "key_password", "label": "Key password (optional)", "type": "password", "default": ""},
                    {"name": "secret", "label": "RADIUS secret (Empty for default)", "type": "password", "default": ""},
                    {"name": "timeout", "label": "Timeout (seconds)", "type": "text", "default": "20"},
                ],
            },
        },
    },
    "radclient": {
        "label": "radclient (raw RADIUS)",
        "desc": "Sends a PAP Access-Request (MAB-style) to PacketFence RADIUS.",
        "variants": {
            "PAP": {
                "label": "PAP Access-Request (MAB)",
                "fields": [
                    {"name": "username", "label": "User-Name (MAC, no separators)", "type": "text", "default": "aabbccddeeff"},
                    {"name": "password", "label": "User-Password (usually = MAC)", "type": "text", "default": "aabbccddeeff"},
                    {"name": "nas_ip", "label": "NAS-IP-Address (must match a switch in switches.conf)", "type": "text", "default": "192.168.0.1"},
                    {"name": "calling_station", "label": "Calling-Station-Id (client MAC, optional)", "type": "text", "default": "aa:bb:cc:dd:ee:ff"},
                    {"name": "called_station", "label": "Called-Station-Id (switch MAC, optional)", "type": "text", "default": ""},
                    {"name": "timeout", "label": "Timeout (seconds)", "type": "text", "default": "20"},
                ],
            },
        },
    },
    "tcpdump": {
        "label": "tcpdump (packet capture)",
        "desc": "Bounded capture on the host; only a structured tshark summary "
                "(no raw payloads) is analyzed.",
        "capture": True,
        "variants": {
            "capture": {
                "label": "capture + analyze",
                "fields": [
                    {"name": "iface", "label": "Interface", "type": "select", "options": [], "default": ""},
                    {"name": "preset", "label": "Preset", "type": "select",
                     "options": ["radius", "dhcp", "dns", "eap", "all"], "default": "radius"},
                    {"name": "filter", "label": "BPF filter (optional — overrides preset)", "type": "text", "default": ""},
                    {"name": "seconds", "label": "Seconds (max 60)", "type": "text", "default": "20"},
                    {"name": "packets", "label": "Packets (max 500)", "type": "text", "default": "200"},
                ],
            },
        },
    },
}


@app.get("/testtools")
def testtools_meta():
    return JSONResponse({"tools": TESTTOOLS_META, "enabled": bool(os.path.exists(TESTTOOL_SOCK))})


@app.get("/testtools/health")
def testtools_health():
    resp = _testtool_call({"action": "health", "deep": True}, timeout=8.0)
    return JSONResponse(resp)


@app.post("/write/testtools/run")
def testtools_run(payload: dict, request: Request):
    # executes a binary on the host: write-gated, and under /write/ so the
    # PacketFence AAA layer resolves it to CHATBOT_WRITE by path.
    if not may_write(request):
        return deny_write()
    tool = payload.get("tool", "")
    if tool not in TESTTOOLS_META:
        return JSONResponse({"ok": False, "error": "unknown tool"}, status_code=400)
    params = payload.get("params") or {}
    if payload.get("eap"):
        params = {**params, "eap": payload["eap"]}
    resp = _testtool_call({"tool": tool, "params": params, "preview": bool(payload.get("preview"))},
                          timeout=65.0)
    return JSONResponse(resp)


@app.post("/write/testtools/capture")
def testtools_capture(payload: dict, request: Request):
    if not may_write(request):
        return deny_write()
    params = payload.get("params") or {}
    # capture can take up to CAP_MAX_SECONDS on the host; allow generous timeout
    resp = _testtool_call({"action": "capture", "params": params,
                           "preview": bool(payload.get("preview"))},
                          timeout=90.0)
    return JSONResponse(resp)


def _provider_names() -> list[str]:
    reg = getattr(providers, "_REGISTRY", None)
    return sorted(reg.keys()) if isinstance(reg, dict) else ["anthropic", "openai"]


@app.get("/models")
def get_models():
    """List models available to the active provider's API key. Returns the
    current model plus the fetched list (newest/recommended flagged)."""
    prov = _state.get("provider")
    cfg = _state.get("cfg") or {}
    if prov is None:
        return JSONResponse({"error": "no provider configured"}, status_code=400)
    if not hasattr(prov, "list_models"):
        return JSONResponse({"provider": cfg.get("provider", ""), "current": prov.model,
                             "models": [], "note": "provider does not support listing models"})
    try:
        models = prov.list_models()
    except Exception as e:
        return JSONResponse({"error": f"could not fetch models: {e}"}, status_code=502)
    return JSONResponse({
        "provider": cfg.get("provider", ""),
        "current": prov.model,
        "models": models,
    })


@app.post("/write/models")
def switch_model(payload: dict, request: Request):
    """Switch the active model (keeps the same provider + key)."""
    if not may_write(request):
        return deny_write()
    model = (payload.get("model") or "").strip()
    if not model:
        return JSONResponse({"error": "model required"}, status_code=400)
    with _cfg_lock:
        cur = _state.get("cfg") or {}
        if not cur.get("provider") or not cur.get("api_key"):
            return JSONResponse({"error": "no provider configured"}, status_code=400)
        cfg = {"provider": cur["provider"], "api_key": cur["api_key"],
               "model": model, "source": cur.get("source", "override")}
        try:
            _apply_provider(cfg)
        except Exception as e:
            return JSONResponse({"error": str(e)}, status_code=400)
        # persist as an override so it survives restarts (unless env-only)
        _save_overrides({"provider": cfg["provider"], "api_key": cfg["api_key"], "model": model})
        return JSONResponse({"ok": True, "provider": cfg["provider"], "model": model})


@app.post("/write/settings/test")
def test_settings(payload: dict, request: Request):
    """Test an API key without saving it. Uses the provided key, or the currently
    saved key for that provider if none is given. Returns a concise result."""
    if not may_write(request):
        return deny_write()
    provider = (payload.get("provider") or "").strip().lower()
    api_key = (payload.get("api_key") or "").strip()
    model = (payload.get("model") or "").strip() or None
    if provider not in _provider_names():
        return JSONResponse({"ok": False, "error": f"unknown provider {provider!r}"}, status_code=400)
    if not api_key:
        cur = _state.get("cfg") or {}
        if provider == cur.get("provider") and cur.get("api_key"):
            api_key = cur["api_key"]
        else:
            return JSONResponse({"ok": False, "error": "enter an API key to test"}, status_code=400)
    return JSONResponse(_test_api_key(provider, api_key, model))


@app.get("/settings")
def get_settings():
    cfg = _state.get("cfg") or {}
    key = cfg.get("api_key") or ""
    return JSONResponse(
        {
            "provider": cfg.get("provider") or PROVIDER or "",
            "model": cfg.get("model") or MODEL or "",
            "source": cfg.get("source", "env"),
            "key_hint": ("\u2026" + key[-4:]) if len(key) >= 8 else ("set" if key else ""),
            "providers": _provider_names(),
            "env_default": bool(PROVIDER and API_KEY),
        }
    )


@app.post("/write/settings")
def post_settings(payload: dict, request: Request):
    if not may_write(request):
        return deny_write()
    with _cfg_lock:
        if payload.get("reset"):
            _clear_overrides()
            cfg = {"provider": PROVIDER, "api_key": API_KEY, "model": MODEL, "source": "env"}
            if not cfg["provider"] or not cfg["api_key"]:
                _state["provider"] = None
                _state["cfg"] = {"provider": "", "api_key": "", "model": "", "source": "env"}
                return JSONResponse({"ok": True, "provider": "", "model": "",
                                     "note": "reset; no defaults in .env, so no provider is active"})
            try:
                _apply_provider(cfg)
            except Exception as e:
                return JSONResponse({"error": f"reset failed: {e}"}, status_code=400)
            c = _state["cfg"]
            return JSONResponse({"ok": True, "provider": c["provider"], "model": c["model"], "source": "env"})

        provider = (payload.get("provider") or "").strip().lower()
        api_key = (payload.get("api_key") or "").strip()
        model = (payload.get("model") or "").strip() or None
        if provider not in _provider_names():
            return JSONResponse({"error": f"unknown provider {provider!r}"}, status_code=400)

        cur = _state.get("cfg") or {}
        if not api_key:
            # keep the existing key only when the provider isn't changing
            if provider == cur.get("provider") and cur.get("api_key"):
                api_key = cur["api_key"]
            else:
                return JSONResponse({"error": "API key required for this provider"}, status_code=400)

        cfg = {"provider": provider, "api_key": api_key, "model": model, "source": "override"}
        try:
            _apply_provider(cfg)
        except Exception as e:
            return JSONResponse({"error": str(e)}, status_code=400)
        _save_overrides({"provider": provider, "api_key": api_key, "model": model})
        c = _state["cfg"]
        return JSONResponse({"ok": True, "provider": c["provider"], "model": c["model"], "source": "override"})


@app.post("/write/confirm_write")
def confirm_write(payload: dict, request: Request):
    """Execute a previously-pended write operation after explicit user approval.
    The agent cannot reach this — only the UI's confirm dialog calls it."""
    # a read-only admin role may ask, but may not execute
    if not may_write(request):
        return deny_write()
    token = (payload.get("confirm_token") or "").strip()
    approved = bool(payload.get("approved"))
    pend = _pending_writes.pop(token, None)
    if not pend:
        return JSONResponse({"error": "unknown or expired confirmation"}, status_code=400)
    if time.time() - pend["created"] > _PENDING_TTL:
        return JSONResponse({"error": "confirmation expired; please retry"}, status_code=400)
    if not approved:
        return JSONResponse({"cancelled": True})
    # run it for real (confirmed=True bypasses the guard)
    result = invoke(pend["oid"], pend["path_params"], pend["query_params"],
                    pend["body"], confirmed=True)
    # PacketFence reports success even when it ignored the fields we sent, so
    # read the record back and hand the caller the actual resulting state.
    if isinstance(result, dict) and 200 <= (result.get("status_code") or 0) < 300:
        rb = _readback(pend["oid"], pend["path_params"])
        if rb:
            result["verification"] = rb
    return JSONResponse({"executed": True, "result": result})


@app.post("/chat")
def chat(payload: dict, request: Request):
    message = (payload.get("message") or "").strip()
    tid = payload.get("thread_id")
    if not message:
        return JSONResponse({"error": "empty message"}, status_code=400)

    # Don't create or persist anything while the index is still warming up.
    if not _state.get("ready"):
        return JSONResponse(
            {
                "reply": "Still starting up — indexing the API spec and documentation. "
                         "This takes a moment on first boot; try again shortly.",
                "activity": [],
                "thread_id": tid,
            }
        )

    pid = current_pid(request)
    now = time.time()
    if not tid or not store.thread_exists(pid, tid):
        # the database assigns the thread id (bigint AUTO_INCREMENT)
        title = message[:60] + ("\u2026" if len(message) > 60 else "")
        tid = store.create_thread(pid, title, now)

    # file tools act on this user + conversation
    _cur_pid.set(pid)
    _cur_tid.set(tid)
    _produced_files.set([])
    _can_write.set(may_write(request))
    run_id = str(payload.get("run_id") or "").strip()[:64]
    _run_id.set(run_id)
    _run_begin(run_id, pid)

    history = _window_history(store.history(pid, tid))
    history.append({"role": "user", "content": message})
    cancelled = False
    try:
        reply, activity, usage = run_agent(history, debug=bool(payload.get("debug")),
                                           thread_id=tid, pid=pid)
    except RunCancelled:
        # Stopped at a tool boundary. Persist the exchange so the thread stays
        # coherent, and say plainly that the answer is incomplete.
        cancelled = True
        # _dbg_events holds (timestamp, line) tuples; flatten them the same way
        # run_agent does so the trace renders identically
        ev = _dbg_events.get() or []
        activity = [line for _, line in sorted(ev, key=lambda e: e[0])]
        activity.append("\u00b7 stopped by the user before the next model call")
        reply = ("**Stopped.** I ended this run at the last tool call, before "
                 "spending another model call. Nothing was left half-applied — "
                 "writes still require confirmation. Ask again to continue.")
        usage = {}
    finally:
        _run_end(run_id)

    now2 = time.time()
    store.add_message(pid, tid, "user", message, None, now)
    assistant_msg_id = store.add_message(pid, tid, "assistant", reply, activity, now2)
    store.touch_thread(pid, tid, now2)
    if usage.get("input_tokens") or usage.get("output_tokens"):
        cfg = _state.get("cfg") or {}
        store.record_usage(pid, cfg.get("provider", "?"), cfg.get("model", "?"),
                           usage.get("input_tokens", 0), usage.get("output_tokens", 0),
                           tid, now2)

    resp = {"reply": reply, "activity": activity, "thread_id": tid,
            "message_id": assistant_msg_id}
    pend = _pending_confirm.get()
    if pend:
        resp["confirm"] = pend
    na = _node_actions.get()
    if na:
        resp["node_actions"] = na
    pt = _prepare_test.get()
    if pt:
        resp["prepare_test"] = pt
    pc = _prepare_capture.get()
    if pc:
        resp["prepare_capture"] = pc

    # The model is told to say "confirm in the dialog below" when a write is
    # staged — and can produce that sentence without having called the tool, in
    # which case nothing is staged and the user waits for a dialog that will
    # never render. Catch the broken promise rather than leaving them guessing.
    if not resp.get("confirm") and _PROMISED_CONFIRM_RE.search(reply or ""):
        print("[pf-bot] model promised a confirmation dialog without staging a write")
        resp["reply"] = (reply.rstrip()
                         + "\n\n---\n\n**No confirmation dialog was created** — I described "
                           "that change without actually requesting it, so nothing is pending "
                           "and nothing has been altered. Ask me again to perform it.")
    if cancelled:
        resp["cancelled"] = True
    files = _produced_files.get() or []
    if files:
        # tie them to the reply so the UI can show download links under it
        for f in files:
            try:
                store.attach_file_to_message(pid, f["id"], assistant_msg_id)
            except Exception:
                pass
        resp["files"] = files
    return JSONResponse(resp)


@app.get("/files")
def list_files(request: Request, thread_id: str = "", kind: str = ""):
    """Files attached to a conversation (or all of this user's files)."""
    pid = current_pid(request)
    return JSONResponse({"files": store.list_files(pid, thread_id or None, kind or None),
                         "quotas": store.quotas(),
                         "used_bytes": store.usage_bytes(pid, thread_id or None)})


@app.post("/files/upload")
async def upload_file(request: Request, file: UploadFile = File(...),
                      thread_id: str = Form("")):
    """Accept a user upload. Uploads are NOT indexed for search — the assistant
    reads them on demand with pf_read_file."""
    pid = current_pid(request)
    tid = (thread_id or "").strip()
    if not tid or not store.thread_exists(pid, tid):
        tid = store.create_thread(pid, (file.filename or "upload")[:60], time.time())
    data = await file.read()
    try:
        rec = store.add_file(pid, tid, file.filename or "upload", data,
                             file.content_type or "", kind="upload")
    except store.FileTooLarge as e:
        return JSONResponse({"error": str(e)}, status_code=413)
    except store.QuotaExceeded as e:
        return JSONResponse({"error": str(e)}, status_code=507)
    except Exception as e:
        return JSONResponse({"error": f"upload failed: {e}"}, status_code=500)
    return JSONResponse({"ok": True, "thread_id": tid, **rec})


@app.get("/files/{fid}/download")
def download_file(fid: int, request: Request):
    rec = store.get_file(current_pid(request), fid)
    if not rec:
        return JSONResponse({"error": "file not found"}, status_code=404)
    if rec.get("data") is None:
        return JSONResponse({"error": rec.get("error", "content unavailable")}, status_code=410)
    name = rec["name"].replace('"', "")
    return Response(content=rec["data"], media_type=rec["mime"],
                    headers={"Content-Disposition": f'attachment; filename="{name}"',
                             "X-Content-Type-Options": "nosniff"})


@app.delete("/files/{fid}")
def remove_file(fid: int, request: Request):
    ok = store.delete_file(current_pid(request), fid)
    return JSONResponse({"ok": ok}, status_code=200 if ok else 404)


@app.post("/cancel")
def cancel_run(payload: dict, request: Request):
    """Ask an in-flight chat run to stop.

    The run ends at its next tool boundary, so the remaining model calls are
    never made. The completion already in flight cannot be aborted — its tokens
    are already committed."""
    return JSONResponse(_run_cancel(str(payload.get("run_id") or "").strip(),
                                    current_pid(request)))


@app.get("/roles")
def list_roles_endpoint(request: Request):
    """Roles with their numeric category_id, for the inspector's role picker."""
    current_pid(request)
    return JSONResponse(list_roles(""))


@app.get("/node/{mac}")
def node_refresh(mac: str, request: Request):
    """Re-read one node for the inspector.

    Deliberately does NOT go through the model: a refresh should be instant,
    deterministic and free of token cost."""
    current_pid(request)
    res = node_details(mac)
    if res.get("error"):
        return JSONResponse({"error": res["error"]}, status_code=404)
    return JSONResponse({"node_actions": res.get("node_actions") or {"mac": mac},
                         "node": res.get("node")})


@app.post("/write/node/{mac}/reevaluate")
def node_reevaluate(mac: str, request: Request):
    """Re-apply policy to one node, without going through the model.

    PacketFence exposes this as POST /node/{id}/reevaluate_access; resolving it
    directly is both faster and more reliable than asking the model to find it."""
    if not may_write(request):
        return deny_write()
    current_pid(request)
    if not _MAC_RE.match((mac or "").strip()):
        return JSONResponse({"error": "invalid MAC"}, status_code=400)
    oids = _node_action_ops("reevaluate_access")
    if not oids:
        return JSONResponse(
            {"error": "this PacketFence build exposes no /node/{id}/reevaluate_access "
                      "endpoint in its API spec"}, status_code=404)
    return _stage_node_write(mac, oids[0], None, "reevaluate access (re-apply policy)")


@app.post("/write/node/{mac}/status")
def node_set_status(mac: str, payload: dict, request: Request):
    """Register or deregister one node. Same reason as above: deterministic and
    immediate, instead of several model turns spent searching for the endpoint."""
    if not may_write(request):
        return deny_write()
    current_pid(request)
    if not _MAC_RE.match((mac or "").strip()):
        return JSONResponse({"error": "invalid MAC"}, status_code=400)
    want = str(payload.get("status", "")).strip().lower()
    if want not in ("reg", "unreg", "registered", "unregistered"):
        return JSONResponse({"error": "status must be reg or unreg"}, status_code=400)
    want = "reg" if want.startswith("reg") else "unreg"
    oids = _node_update_ops()
    if not oids:
        return JSONResponse({"error": "no single-node update operation in the API spec"},
                            status_code=404)
    verb = "register" if want == "reg" else "deregister"
    return _stage_node_write(mac, oids[0], {"status": want}, f"{verb} this node")


@app.post("/write/node/{mac}/role")
def node_set_role(mac: str, payload: dict, request: Request):
    """Prepare a role change for confirmation.

    Returns the same confirmation payload a chat-driven write produces, so the
    existing confirm card, /confirm_write handler and post-write read-back all
    apply unchanged — the UI shortcut never bypasses the write guard."""
    if not may_write(request):
        return deny_write()
    current_pid(request)
    if not _MAC_RE.match((mac or "").strip()):
        return JSONResponse({"error": "invalid MAC"}, status_code=400)
    want = str(payload.get("category_id", payload.get("role", ""))).strip()
    if not want:
        return JSONResponse({"error": "category_id or role is required"}, status_code=400)
    resolved = list_roles(want)
    if resolved.get("error"):
        return JSONResponse(resolved, status_code=400)
    cid = resolved["category_id"]

    ops = _state.get("ops", {}) or {}
    for oid in _node_update_ops():
        o = ops.get(oid)
        if not o:
            continue
        m = _PATH_PARAM_RE.search(o.get("path", ""))
        pname = m.group(0)[1:-1] if m else "node_id"
        res = invoke(oid, path_params={pname: mac}, body={"category_id": cid})
        if isinstance(res, dict) and res.get("confirmation_required"):
            res["summary"] = f"set role to {resolved.get('name', cid)} (category_id {cid})"
            return JSONResponse({"confirm": res, "category_id": cid})
        return JSONResponse({"error": "unexpected response preparing the change",
                             "result": res}, status_code=500)
    return JSONResponse({"error": "no single-node update operation found in the API spec"},
                        status_code=404)


@app.get("/config")
def get_config():
    return JSONResponse({"pf_admin_url": PF_ADMIN_URL,
                         "pf_version": _state.get("pf_version") or ""})


# ── static UI ────────────────────────────────────────────────────────────────
# The page computes its own base path from location.pathname (see index.html),
# so no server-side injection is needed; behind the admin proxy Caddy strips
# /api/v1/pfchatbot before requests reach us, exactly as for the API routes.
# MUST stay the last route registration in this file: a mount at "/" is matched
# after the explicit routes above, so it serves index.html and any future
# assets without shadowing /chat, /config, /write/*, etc.
app.mount("/", StaticFiles(
    directory=os.path.join(os.path.dirname(os.path.abspath(__file__)), "static"),
    html=True), name="ui")
