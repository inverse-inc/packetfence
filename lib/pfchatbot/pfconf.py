"""
PacketFence ini configuration for the assistant.

The assistant's settings live in the [pfchatbot] section of pf.conf, edited
from the admin UI (Configuration > Integration > NACBot) through
the standard /api/v1/config/base/pfchatbot endpoint. pf.conf.defaults supplies
the defaults; pf.conf holds what the administrator changed.

Precedence, per key: a non-empty ini value (pf.conf over pf.conf.defaults),
else the environment (pfchatbot.env / .env), else the code default. The env
remains the fallback so a standalone run without PacketFence's conf dir still
works.

The conf DIRECTORY must be mounted, not single files: PacketFence rewrites
pf.conf with write-to-temp + rename, so a single-file bind mount keeps serving
the old inode and never sees a change.
"""
from __future__ import annotations

import os

PF_CONF_DIR = os.environ.get("PF_CONF_DIR", "/usr/local/pf/conf")
SECTION = "pfchatbot"

# ini key -> (env name, ini->env value conversion)
_toggle = lambda v: "true" if v == "enabled" else "false"
_mb = lambda v: str(int(float(v) * 1024 * 1024))
KEYS = {
    "provider":          ("PROVIDER", None),
    "api_key":           ("API_KEY", None),
    "model":             ("MODEL", None),
    "pf_username":       ("PF_USERNAME", None),
    "pf_password":       ("PF_PASSWORD", None),
    "pf_verify_tls":     ("PF_VERIFY_TLS", _toggle),
    "llm_timeout":       ("LLM_TIMEOUT", None),
    "llm_retries":       ("LLM_RETRIES", None),
    "rag_embed_model":   ("RAG_EMBED_MODEL", None),
    "rag_rerank_model":  ("RAG_RERANK_MODEL", None),
    "file_max":          ("CHATBOT_FILE_MAX", _mb),
    "file_thread_quota": ("CHATBOT_FILE_THREAD_QUOTA", _mb),
    "file_user_quota":   ("CHATBOT_FILE_USER_QUOTA", _mb),
    "upload_ttl_days":   ("CHATBOT_UPLOAD_TTL_DAYS", None),
}
# Applied live (re-read when pf.conf changes); everything else needs a restart.
LIVE_KEYS = ("provider", "api_key", "model")


def read_ini_section(path: str, want: set) -> dict:
    out, section = {}, None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    section = line[1:-1].strip().lower()
                    continue
                if section in want and "=" in line:
                    k, v = line.split("=", 1)
                    v = v.strip()
                    if "[%" in v:        # unexpanded template (pf.conf.defaults)
                        continue
                    out[k.strip().lower()] = v
    except OSError:
        pass
    return out


def _path(name: str) -> str:
    return os.path.join(PF_CONF_DIR, name)


def section() -> dict:
    """The [pfchatbot] section, pf.conf layered over pf.conf.defaults."""
    merged = read_ini_section(_path("pf.conf.defaults"), {SECTION})
    merged.update(read_ini_section(_path("pf.conf"), {SECTION}))
    return merged


def _env_value(key: str, raw: str) -> str:
    conv = KEYS[key][1]
    try:
        return conv(raw) if conv else raw
    except (TypeError, ValueError):
        print(f"[pf-bot] pf.conf [{SECTION}] {key}={raw!r} is invalid; ignored", flush=True)
        return ""


def apply_to_environ() -> None:
    """Export every non-empty ini value into os.environ before the module-level
    settings are read, so the ini wins over pfchatbot.env."""
    for key, raw in section().items():
        if key in KEYS and raw != "":
            val = _env_value(key, raw)
            if val != "":
                os.environ[KEYS[key][0]] = val


def mtime() -> float:
    try:
        return os.stat(_path("pf.conf")).st_mtime
    except OSError:
        return 0.0


def live_settings(env_defaults: dict) -> dict:
    """provider / api_key / model as currently configured: ini, else the
    values the process started with from the environment."""
    sec = section()
    return {k: (sec.get(k) or env_defaults.get(k) or "") for k in LIVE_KEYS}
