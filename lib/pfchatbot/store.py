"""Conversation storage for the PacketFence chatbot.

Threads, messages and token usage live in PacketFence's own MySQL/MariaDB
database (`pf` by default) instead of a local SQLite file, so history survives
container rebuilds and is visible to the rest of the deployment.

Design notes
------------
* **Per-user.** Every row is keyed by `pid` (a PacketFence person). The primary
  key starts with `pid` and a foreign key cascades from `person`, so deleting a
  person removes their conversations automatically. Users never see each
  other's threads: every query is scoped by pid.
* **Compression.** The tables are `ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8`.
  Chat transcripts and log excerpts are highly repetitive and compress ~50% on
  disk. Compression is at the InnoDB *page* level, which is what makes the next
  point possible.
* **Still searchable.** Because compression is transparent to the engine,
  normal indexes keep working — including `FULLTEXT` on the thread title and
  the message body. Compressing the columns instead (e.g. `COMPRESS()` or
  gzip in Python) would have made the text unindexable and unsearchable.
* **Charset matching.** `person.pid` is often utf8mb3 while the database
  defaults to utf8mb4; creating the child table without matching the parent
  column exactly fails with errno 150. The pid column definition is therefore
  read from information_schema at init and mirrored.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import threading
import time

import pymysql
from pymysql.cursors import DictCursor

# ── config ───────────────────────────────────────────────────────────────────
DB_HOST = os.environ.get("CHATBOT_DB_HOST", os.environ.get("PF_DB_HOST", "host.docker.internal"))
DB_PORT = int(os.environ.get("CHATBOT_DB_PORT", os.environ.get("PF_DB_PORT", "3306")))
DB_NAME = os.environ.get("CHATBOT_DB_NAME", os.environ.get("PF_DB_NAME", "pf"))
DB_USER = os.environ.get("CHATBOT_DB_USER", os.environ.get("PF_DB_USER", "pf"))
DB_PASS = os.environ.get("CHATBOT_DB_PASSWORD", os.environ.get("PF_DB_PASSWORD", ""))
DB_SOCKET = os.environ.get("CHATBOT_DB_SOCKET", "")          # optional unix socket

# Zero-touch default: when no password is configured, read PacketFence's own
# [database] credentials from pf.conf (mounted read-only by the service unit).
# An explicit CHATBOT_DB_* block always wins — use it with a dedicated,
# least-privilege DB user when hardening matters more than zero-config.
# Layered like PF's own config: defaults first, pf.conf overrides; pfconfig.conf
# ([mysql] section) covers containerized installs that keep credentials there.
PF_CONF_DIR = os.environ.get("PF_CONF_DIR", "/usr/local/pf/conf")

def _read_ini_section(path: str, want: set) -> dict:
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

def _pf_conf_database() -> dict:
    merged = {}
    for fname, sections in (("pf.conf.defaults", {"database"}),
                            ("pfconfig.conf",   {"mysql"}),
                            ("pf.conf",         {"database"})):
        merged.update(_read_ini_section(os.path.join(PF_CONF_DIR, fname), sections))
    return merged

if not DB_PASS:
    _pfdb = _pf_conf_database()
    if _pfdb.get("pass"):
        DB_PASS = _pfdb["pass"]
        if "CHATBOT_DB_USER" not in os.environ and _pfdb.get("user"):
            DB_USER = _pfdb["user"]
        if "CHATBOT_DB_NAME" not in os.environ and _pfdb.get("db"):
            DB_NAME = _pfdb["db"]
        if not DB_SOCKET and os.path.exists("/var/lib/mysql/mysql.sock"):
            DB_SOCKET = "/var/lib/mysql/mysql.sock"
        print(f"[pf-bot] store: using PacketFence's database credentials "
              f"(user={DB_USER}, socket={DB_SOCKET or 'tcp'}); set CHATBOT_DB_* to override", flush=True)
PREFIX = os.environ.get("CHATBOT_TABLE_PREFIX", "chatbot_")
DEFAULT_PID = os.environ.get("CHATBOT_DEFAULT_PID", "admin")
KEY_BLOCK_SIZE = int(os.environ.get("CHATBOT_KEY_BLOCK_SIZE", "8"))

# ── file attachments ─────────────────────────────────────────────────────────
# Small artifacts live inline in the row (they inherit the per-user cascade and
# the table's compression); anything larger spills to a content-addressed file
# so blobs don't bloat mysqldump / replication / the InnoDB buffer pool.
FILE_DIR = os.environ.get("CHATBOT_FILE_DIR", "/var/lib/pf-chatbot/files")
FILE_INLINE_MAX = int(os.environ.get("CHATBOT_FILE_INLINE_MAX", 256 * 1024))
FILE_MAX = int(os.environ.get("CHATBOT_FILE_MAX", 8 * 1024 * 1024))
FILE_THREAD_QUOTA = int(os.environ.get("CHATBOT_FILE_THREAD_QUOTA", 50 * 1024 * 1024))
FILE_USER_QUOTA = int(os.environ.get("CHATBOT_FILE_USER_QUOTA", 500 * 1024 * 1024))
UPLOAD_TTL_DAYS = int(os.environ.get("CHATBOT_UPLOAD_TTL_DAYS", "30"))

T_THREAD = PREFIX + "thread"
T_MSG = PREFIX + "message"
T_USAGE = PREFIX + "usage"
T_FILE = PREFIX + "file"
T_FILE = PREFIX + "file"

_local = threading.local()
_init_lock = threading.Lock()
_state = {"ready": False, "error": None, "ft_min": 3}


def _tid(thread_id):
    """Thread ids are DB-generated bigints but travel as strings through the API
    and UI. Returns None for anything non-numeric (e.g. a pre-migration uuid),
    so a stale id is a clean miss rather than a SQL error."""
    try:
        return int(str(thread_id).strip())
    except (TypeError, ValueError):
        return None


class StoreUnavailable(RuntimeError):
    """Raised when the database cannot be reached or the schema can't be created."""


# ── connection handling ──────────────────────────────────────────────────────
def _connect():
    kw = dict(user=DB_USER, password=DB_PASS, database=DB_NAME,
              charset="utf8mb4", autocommit=True, cursorclass=DictCursor,
              connect_timeout=10, read_timeout=30, write_timeout=30)
    if DB_SOCKET:
        kw["unix_socket"] = DB_SOCKET
    else:
        kw["host"] = DB_HOST
        kw["port"] = DB_PORT
    return pymysql.connect(**kw)


def conn():
    """A live connection for this thread, reconnecting if the server dropped it."""
    c = getattr(_local, "conn", None)
    if c is not None:
        try:
            c.ping(reconnect=True)
            return c
        except Exception:
            try:
                c.close()
            except Exception:
                pass
            _local.conn = None
    _local.conn = _connect()
    return _local.conn


def _q(sql: str, args=(), fetch: str = "all"):
    """Run a statement, retrying once if the connection went away mid-flight."""
    for attempt in (0, 1):
        try:
            with conn().cursor() as cur:
                cur.execute(sql, args)
                if fetch == "all":
                    return cur.fetchall()
                if fetch == "one":
                    return cur.fetchone()
                if fetch == "id":
                    return cur.lastrowid
                return cur.rowcount
        except (pymysql.err.OperationalError, pymysql.err.InterfaceError):
            _local.conn = None
            if attempt:
                raise


# ── schema ───────────────────────────────────────────────────────────────────
def _pid_column_ddl() -> str:
    """Mirror person.pid exactly — a type/charset/collation mismatch makes the
    foreign key fail with errno 150."""
    row = _q(
        "SELECT COLUMN_TYPE ct, CHARACTER_SET_NAME cs, COLLATION_NAME co "
        "FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=%s AND TABLE_NAME='person' AND COLUMN_NAME='pid'",
        (DB_NAME,), fetch="one")
    if not row:
        raise StoreUnavailable(
            f"table `{DB_NAME}`.`person` not found — the chatbot stores conversations "
            f"alongside PacketFence and keys them to person.pid")
    ct, cs, co = row["ct"], row["cs"], row["co"]
    spec = ct
    if cs:
        spec += f" CHARACTER SET {cs}"
    if co:
        spec += f" COLLATE {co}"
    return spec


def init() -> None:
    """Create the tables if absent. Safe to call repeatedly."""
    with _init_lock:
        if _state["ready"]:
            return
        pid_ddl = _pid_column_ddl()
        opts = f"ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE={KEY_BLOCK_SIZE}"

        _q(f"""CREATE TABLE IF NOT EXISTS `{T_THREAD}` (
              `pid` {pid_ddl} NOT NULL,
              `thread_id` bigint(20) NOT NULL AUTO_INCREMENT,
              `title` varchar(255) NOT NULL,
              `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
              `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
              PRIMARY KEY (`pid`,`thread_id`),
              UNIQUE KEY `uk_thread_id` (`thread_id`),
              KEY `idx_thread_recent` (`pid`,`updated`),
              FULLTEXT KEY `ft_thread_title` (`title`),
              CONSTRAINT `fk_{PREFIX}thread_person` FOREIGN KEY (`pid`)
                REFERENCES `person` (`pid`) ON DELETE CASCADE
            ) {opts}""", fetch="none")

        _q(f"""CREATE TABLE IF NOT EXISTS `{T_MSG}` (
              `pid` {pid_ddl} NOT NULL,
              `thread_id` bigint(20) NOT NULL,
              `id` bigint(20) NOT NULL AUTO_INCREMENT,
              `role` varchar(16) NOT NULL,
              `content` mediumtext NOT NULL,
              `activity` mediumtext DEFAULT NULL,
              `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
              `feedback` tinyint(1) NOT NULL DEFAULT 0,
              PRIMARY KEY (`id`),
              KEY `idx_msg_thread` (`pid`,`thread_id`,`id`),
              KEY `idx_msg_feedback` (`pid`,`feedback`,`id`),
              FULLTEXT KEY `ft_msg_content` (`content`),
              CONSTRAINT `fk_{PREFIX}msg_thread` FOREIGN KEY (`pid`,`thread_id`)
                REFERENCES `{T_THREAD}` (`pid`,`thread_id`) ON DELETE CASCADE
            ) {opts}""", fetch="none")

        _q(f"""CREATE TABLE IF NOT EXISTS `{T_USAGE}` (
              `pid` {pid_ddl} NOT NULL,
              `id` bigint(20) NOT NULL AUTO_INCREMENT,
              `ts` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
              `provider` varchar(32) NOT NULL,
              `model` varchar(128) NOT NULL,
              `input_tokens` int(11) NOT NULL DEFAULT 0,
              `output_tokens` int(11) NOT NULL DEFAULT 0,
              `thread_id` bigint(20) DEFAULT NULL,
              PRIMARY KEY (`pid`,`id`),
              UNIQUE KEY `uk_usage_id` (`id`),
              KEY `idx_usage_ts` (`pid`,`ts`),
              CONSTRAINT `fk_{PREFIX}usage_person` FOREIGN KEY (`pid`)
                REFERENCES `person` (`pid`) ON DELETE CASCADE
            ) {opts}""", fetch="none")

        _q(f"""CREATE TABLE IF NOT EXISTS `{T_FILE}` (
              `pid` {pid_ddl} NOT NULL,
              `thread_id` bigint(20) NOT NULL,
              `id` bigint(20) NOT NULL AUTO_INCREMENT,
              `message_id` bigint(20) DEFAULT NULL,
              `kind` varchar(8) NOT NULL,
              `name` varchar(255) NOT NULL,
              `mime` varchar(128) NOT NULL DEFAULT 'application/octet-stream',
              `size_bytes` bigint(20) NOT NULL,
              `sha256` char(64) NOT NULL,
              `content` mediumblob DEFAULT NULL,
              `disk_path` varchar(255) DEFAULT NULL,
              `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
              PRIMARY KEY (`id`),
              KEY `idx_file_thread` (`pid`,`thread_id`,`created`),
              KEY `idx_file_msg` (`pid`,`message_id`),
              KEY `idx_file_sha` (`sha256`),
              CONSTRAINT `fk_{PREFIX}file_thread` FOREIGN KEY (`pid`,`thread_id`)
                REFERENCES `{T_THREAD}` (`pid`,`thread_id`) ON DELETE CASCADE
            ) {opts}""", fetch="none")

        row = _q("SELECT @@innodb_ft_min_token_size AS n", fetch="one")
        _state["ft_min"] = int(row["n"]) if row else 3
        _state["ready"] = True
        _state["error"] = None


def ensure() -> None:
    """Initialise lazily; record the failure instead of crashing the request."""
    if _state["ready"]:
        return
    try:
        init()
    except Exception as e:
        _state["error"] = str(e)
        raise StoreUnavailable(str(e))


def status() -> dict:
    return {"ready": _state["ready"], "error": _state["error"],
            "database": DB_NAME, "host": DB_SOCKET or f"{DB_HOST}:{DB_PORT}"}


# ── roles (node categories) ──────────────────────────────────────────────────
# PacketFence's config API identifies a role by NAME, but a node's role is the
# numeric node_category.category_id. Reading the table directly gives the true
# mapping and picks up roles created after this container started, with no
# hardcoded list to go stale.
def roles() -> list[dict]:
    ensure()
    try:
        rows = _q("SELECT category_id, name, notes FROM node_category ORDER BY category_id")
    except Exception as e:
        return [{"error": f"could not read node_category: {e}"}]
    return [{"category_id": int(r["category_id"]), "name": r["name"],
             "notes": r["notes"]} for r in rows]


def role_id(name: str) -> int | None:
    """Numeric category_id for a role name (case-insensitive). None if unknown."""
    name = (name or "").strip()
    if not name:
        return None
    if name.isdigit():
        return int(name)
    for r in roles():
        if r.get("name", "").lower() == name.lower():
            return r["category_id"]
    return None


# ── people ───────────────────────────────────────────────────────────────────
def person_exists(pid: str) -> bool:
    return bool(_q("SELECT 1 AS x FROM person WHERE pid=%s", (pid,), fetch="one"))


def resolve_pid(pid: str | None) -> str:
    """Map a requested user onto a real person row. Falls back to the configured
    default so a missing/unknown user can still use the assistant rather than
    hitting a foreign-key error."""
    ensure()
    pid = (pid or "").strip()
    if pid and person_exists(pid):
        return pid
    if pid:
        print(f"[pf-bot] unknown person {pid!r}; storing under {DEFAULT_PID!r}")
    if person_exists(DEFAULT_PID):
        return DEFAULT_PID
    raise StoreUnavailable(
        f"neither {pid!r} nor the fallback {DEFAULT_PID!r} exists in `person`; "
        f"set CHATBOT_DEFAULT_PID to an existing PacketFence user")


# ── threads ──────────────────────────────────────────────────────────────────
def list_threads(pid: str) -> list[dict]:
    ensure()
    rows = _q(
        f"SELECT t.thread_id AS id, t.title, "
        f"  UNIX_TIMESTAMP(t.created) AS created, UNIX_TIMESTAMP(t.updated) AS updated, "
        f"  (SELECT COUNT(*) FROM `{T_MSG}` m "
        f"    WHERE m.pid=t.pid AND m.thread_id=t.thread_id) AS msg_count "
        f"FROM `{T_THREAD}` t WHERE t.pid=%s ORDER BY t.updated DESC", (pid,))
    # ids travel as strings so the UI can compare them without type surprises
    return [{**r, "id": str(r["id"]),
             "created": float(r["created"] or 0), "updated": float(r["updated"] or 0)}
            for r in rows]


def create_thread(pid: str, title: str, now: float) -> str:
    """Insert a thread and return the id the database assigned."""
    ensure()
    return str(_q(
        f"INSERT INTO `{T_THREAD}`(pid,title,created,updated) "
        f"VALUES(%s,%s,FROM_UNIXTIME(%s),FROM_UNIXTIME(%s))",
        (pid, title[:255], now, now), fetch="id"))


def thread_exists(pid: str, thread_id) -> bool:
    ensure()
    tid = _tid(thread_id)
    if tid is None:
        return False
    return bool(_q(f"SELECT 1 AS x FROM `{T_THREAD}` WHERE pid=%s AND thread_id=%s",
                   (pid, tid), fetch="one"))


def touch_thread(pid: str, thread_id, when: float) -> None:
    _q(f"UPDATE `{T_THREAD}` SET updated=FROM_UNIXTIME(%s) WHERE pid=%s AND thread_id=%s",
       (when, pid, _tid(thread_id)), fetch="none")


def get_thread(pid: str, thread_id: str) -> dict | None:
    ensure()
    tid = _tid(thread_id)
    if tid is None:
        return None
    t = _q(f"SELECT thread_id AS id, title FROM `{T_THREAD}` WHERE pid=%s AND thread_id=%s",
           (pid, tid), fetch="one")
    if not t:
        return None
    rows = _q(f"SELECT id, role, content, activity, feedback FROM `{T_MSG}` "
              f"WHERE pid=%s AND thread_id=%s ORDER BY id", (pid, tid))
    return {"id": str(t["id"]), "title": t["title"], "messages": [
        {"id": r["id"], "role": r["role"], "content": r["content"],
         "activity": json.loads(r["activity"]) if r["activity"] else [],
         # the column is NOT NULL DEFAULT 0; 0 means "no rating"
         "feedback": r["feedback"] or None}
        for r in rows]}


def delete_thread(pid: str, thread_id: str) -> None:
    ensure()
    # messages cascade via the composite foreign key
    _q(f"DELETE FROM `{T_THREAD}` WHERE pid=%s AND thread_id=%s",
       (pid, _tid(thread_id)), fetch="none")


def history(pid: str, thread_id: str) -> list[dict]:
    ensure()
    tid = _tid(thread_id)
    if tid is None:
        return []
    return [{"role": r["role"], "content": r["content"]} for r in
            _q(f"SELECT role, content FROM `{T_MSG}` WHERE pid=%s AND thread_id=%s ORDER BY id",
               (pid, tid))]


# ── messages ─────────────────────────────────────────────────────────────────
def add_message(pid: str, thread_id: str, role: str, content: str,
                activity=None, when: float | None = None) -> int:
    ensure()
    return _q(f"INSERT INTO `{T_MSG}`(pid,thread_id,role,content,activity,created) "
              f"VALUES(%s,%s,%s,%s,%s,FROM_UNIXTIME(%s))",
              (pid, _tid(thread_id), role, content,
               json.dumps(activity) if activity is not None else None,
               when if when is not None else time.time()), fetch="id")


def set_feedback(pid: str, message_id: int, rating: int) -> dict:
    ensure()
    row = _q(f"SELECT role FROM `{T_MSG}` WHERE pid=%s AND id=%s", (pid, message_id), fetch="one")
    if not row:
        return {"error": "message not found"}
    if row["role"] != "assistant":
        return {"error": "can only rate assistant messages"}
    # column is NOT NULL DEFAULT 0, so "cleared" is stored as 0 rather than NULL
    _q(f"UPDATE `{T_MSG}` SET feedback=%s WHERE pid=%s AND id=%s",
       (int(rating), pid, message_id), fetch="none")
    return {"ok": True, "message_id": message_id, "rating": rating}


def liked_examples(pid: str, thread_id: str | None, limit: int = 3) -> list[dict]:
    """Assistant replies this user marked good, current thread first."""
    ensure()
    rows = []
    if thread_id:
        rows = list(_q(f"SELECT content, activity FROM `{T_MSG}` "
                       f"WHERE pid=%s AND feedback=1 AND thread_id=%s ORDER BY id DESC LIMIT %s",
                       (pid, thread_id, limit)))
    if len(rows) < limit:
        extra = limit - len(rows)
        if thread_id:
            rows += list(_q(f"SELECT content, activity FROM `{T_MSG}` "
                            f"WHERE pid=%s AND feedback=1 AND thread_id<>%s ORDER BY id DESC LIMIT %s",
                            (pid, thread_id, extra)))
        else:
            rows += list(_q(f"SELECT content, activity FROM `{T_MSG}` "
                            f"WHERE pid=%s AND feedback=1 ORDER BY id DESC LIMIT %s",
                            (pid, extra)))
    return rows


# ── search ───────────────────────────────────────────────────────────────────
_WORD = re.compile(r"[0-9A-Za-z_]+")


def _boolean_terms(q: str) -> str | None:
    """Build a FULLTEXT BOOLEAN MODE expression, or None when the query is too
    short for the index (InnoDB ignores tokens under innodb_ft_min_token_size)."""
    words = [w for w in _WORD.findall(q) if len(w) >= _state["ft_min"]]
    if not words:
        return None
    return " ".join("+" + w + "*" for w in words[:8])


def search_threads(pid: str, q: str) -> list[dict]:
    """Search this user's threads by title AND message body.

    Uses the FULLTEXT indexes when the query has indexable tokens, and falls
    back to a substring scan for very short queries (e.g. "AD", a VLAN id) or
    when full-text finds nothing — so short, exact strings still work."""
    ensure()
    q = (q or "").strip()
    if not q:
        return list_threads(pid)

    expr = _boolean_terms(q)
    hits: dict[str, dict] = {}

    def _titles(rows):
        for r in rows:
            hits.setdefault(r["thread_id"], {"title_hit": False, "count": 0, "snippet": ""})
            hits[r["thread_id"]]["title_hit"] = True

    def _bodies(rows):
        ql = q.lower()
        for r in rows:
            h = hits.setdefault(r["thread_id"], {"title_hit": False, "count": 0, "snippet": ""})
            content = r["content"] or ""
            n = content.lower().count(ql)
            h["count"] += n or 1          # full-text matched even if not a literal substring
            if not h["snippet"]:
                i = content.lower().find(ql)
                if i < 0:
                    i = 0
                start = max(0, i - 30)
                h["snippet"] = ("…" if start > 0 else "") + content[start:i + len(q) + 40].strip()

    if expr:
        _titles(_q(f"SELECT thread_id FROM `{T_THREAD}` "
                   f"WHERE pid=%s AND MATCH(title) AGAINST(%s IN BOOLEAN MODE)", (pid, expr)))
        _bodies(_q(f"SELECT thread_id, content FROM `{T_MSG}` "
                   f"WHERE pid=%s AND MATCH(content) AGAINST(%s IN BOOLEAN MODE) "
                   f"ORDER BY id LIMIT 500", (pid, expr)))
    if not hits:                          # short query, stopword, or no full-text hit
        like = "%" + q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
        _titles(_q(f"SELECT thread_id FROM `{T_THREAD}` WHERE pid=%s AND title LIKE %s",
                   (pid, like)))
        _bodies(_q(f"SELECT thread_id, content FROM `{T_MSG}` "
                   f"WHERE pid=%s AND content LIKE %s ORDER BY id LIMIT 500", (pid, like)))
    if not hits:
        return []

    meta = {r["id"]: r for r in list_threads(pid)}
    out = []
    for tid, h in hits.items():
        m = meta.get(str(tid))
        if not m:
            continue
        d = dict(m)
        d["match_count"] = h["count"] + (1 if h["title_hit"] else 0)
        d["title_hit"] = h["title_hit"]
        d["snippet"] = h["snippet"]
        out.append(d)
    out.sort(key=lambda r: (r["match_count"], r["updated"]), reverse=True)
    return out


# ── token usage ──────────────────────────────────────────────────────────────
def record_usage(pid: str, provider: str, model: str, inp: int, out: int,
                 thread_id: str | None, when: float | None = None) -> None:
    ensure()
    _q(f"INSERT INTO `{T_USAGE}`(pid,ts,provider,model,input_tokens,output_tokens,thread_id) "
       f"VALUES(%s,FROM_UNIXTIME(%s),%s,%s,%s,%s,%s)",
       (pid, when if when is not None else time.time(), provider or "?", model or "?",
        int(inp or 0), int(out or 0), _tid(thread_id)), fetch="none")


def usage_row_exists(pid: str, ts: float, thread_id: str | None) -> bool:
    """Used by the migration to stay idempotent across re-runs."""
    ensure()
    return bool(_q(f"SELECT 1 AS x FROM `{T_USAGE}` WHERE pid=%s AND ts=FROM_UNIXTIME(%s) "
                   f"AND (thread_id<=>%s) LIMIT 1", (pid, ts, _tid(thread_id)), fetch="one"))


def usage(pid: str) -> dict:
    ensure()
    daily = _q(
        f"SELECT DATE(ts) AS `date`, SUM(input_tokens) AS input_tokens, "
        f"  SUM(output_tokens) AS output_tokens, SUM(input_tokens+output_tokens) AS total_tokens "
        f"FROM `{T_USAGE}` WHERE pid=%s GROUP BY `date` ORDER BY `date` DESC LIMIT 30", (pid,))
    monthly = _q(
        f"SELECT DATE_FORMAT(ts,'%%Y-%%m') AS `month`, SUM(input_tokens) AS input_tokens, "
        f"  SUM(output_tokens) AS output_tokens, SUM(input_tokens+output_tokens) AS total_tokens "
        f"FROM `{T_USAGE}` WHERE pid=%s GROUP BY `month` ORDER BY `month` DESC LIMIT 12", (pid,))
    conv = lambda rows, k: [
        {k: str(r[k]), "input_tokens": int(r["input_tokens"] or 0),
         "output_tokens": int(r["output_tokens"] or 0),
         "total_tokens": int(r["total_tokens"] or 0)} for r in rows]
    return {"daily": conv(daily, "date"), "monthly": conv(monthly, "month")}


# ── file attachments ─────────────────────────────────────────────────────────
class FileTooLarge(ValueError):
    pass


class QuotaExceeded(ValueError):
    pass


def _blob_path(sha: str) -> str:
    """Content-addressed location. The path is derived from a hash of the bytes,
    never from user input, so no pid/filename can escape the file root."""
    return os.path.join(FILE_DIR, sha[:2], sha)


def _safe_name(name: str) -> str:
    """Keep a readable filename for display/download; it is never used as a path."""
    name = os.path.basename((name or "file").strip()) or "file"
    name = re.sub(r"[^\w.\- ]+", "_", name)[:255]
    return name or "file"


def usage_bytes(pid: str, thread_id: str | None = None) -> int:
    ensure()
    if thread_id:
        r = _q(f"SELECT COALESCE(SUM(size_bytes),0) AS n FROM `{T_FILE}` "
               f"WHERE pid=%s AND thread_id=%s", (pid, _tid(thread_id)), fetch="one")
    else:
        r = _q(f"SELECT COALESCE(SUM(size_bytes),0) AS n FROM `{T_FILE}` WHERE pid=%s",
               (pid,), fetch="one")
    return int(r["n"] or 0)


def add_file(pid: str, thread_id: str, name: str, data: bytes, mime: str = "",
             kind: str = "output", message_id: int | None = None) -> dict:
    """Store a file for this user/thread. Small files go inline in the row; larger
    ones spill to a content-addressed blob on disk with the row pointing at it."""
    ensure()
    size = len(data)
    if size > FILE_MAX:
        raise FileTooLarge(f"{size} bytes exceeds the {FILE_MAX} byte limit per file")
    if usage_bytes(pid, thread_id) + size > FILE_THREAD_QUOTA:
        raise QuotaExceeded("this conversation's file quota is full")
    if usage_bytes(pid) + size > FILE_USER_QUOTA:
        raise QuotaExceeded("your file quota is full")

    sha = hashlib.sha256(data).hexdigest()
    inline = size <= FILE_INLINE_MAX
    disk_path = None
    if not inline:
        disk_path = _blob_path(sha)
        if not os.path.isfile(disk_path):          # identical bytes dedupe for free
            os.makedirs(os.path.dirname(disk_path), exist_ok=True)
            tmp = disk_path + ".tmp"
            with open(tmp, "wb") as f:
                f.write(data)
            os.replace(tmp, disk_path)             # atomic: no half-written blobs

    fid = _q(f"INSERT INTO `{T_FILE}`"
             f"(pid,thread_id,message_id,kind,name,mime,size_bytes,sha256,content,disk_path,created) "
             f"VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,FROM_UNIXTIME(%s))",
             (pid, _tid(thread_id), message_id, kind, _safe_name(name),
              mime or "application/octet-stream", size, sha,
              data if inline else None, disk_path, time.time()), fetch="id")
    return {"id": fid, "name": _safe_name(name), "size_bytes": size,
            "mime": mime or "application/octet-stream", "kind": kind,
            "stored": "inline" if inline else "disk"}


def attach_file_to_message(pid: str, file_id: int, message_id: int) -> None:
    """Link an agent-produced file to the reply that created it, so the UI can
    render its download link under that message."""
    _q(f"UPDATE `{T_FILE}` SET message_id=%s WHERE pid=%s AND id=%s",
       (int(message_id), pid, int(file_id)), fetch="none")


def list_files(pid: str, thread_id: str | None = None, kind: str | None = None) -> list[dict]:
    ensure()
    sql = (f"SELECT id, thread_id, message_id, kind, name, mime, size_bytes, "
           f"UNIX_TIMESTAMP(created) AS created, "
           f"(disk_path IS NULL) AS inline FROM `{T_FILE}` WHERE pid=%s")
    args: list = [pid]
    if thread_id:
        sql += " AND thread_id=%s"
        args.append(_tid(thread_id))
    if kind:
        sql += " AND kind=%s"
        args.append(kind)
    sql += " ORDER BY created DESC, id DESC LIMIT 500"
    return [{**r, "inline": bool(r["inline"]), "thread_id": str(r["thread_id"]),
             "created": float(r["created"] or 0)} for r in _q(sql, tuple(args))]


def get_file(pid: str, file_id: int) -> dict | None:
    """Metadata plus bytes, scoped to the owner. Returns None for another user's file."""
    ensure()
    r = _q(f"SELECT id, thread_id, kind, name, mime, size_bytes, sha256, content, disk_path "
           f"FROM `{T_FILE}` WHERE pid=%s AND id=%s", (pid, int(file_id)), fetch="one")
    if not r:
        return None
    data = r["content"]
    if data is None and r["disk_path"]:
        try:
            with open(r["disk_path"], "rb") as f:
                data = f.read()
        except OSError as e:
            return {**r, "data": None, "error": f"blob missing on disk: {e}"}
    return {**r, "data": data or b""}


def delete_file(pid: str, file_id: int) -> bool:
    """Remove the row. The blob is left for the sweeper, since other rows may
    reference the same content-addressed bytes."""
    ensure()
    n = _q(f"DELETE FROM `{T_FILE}` WHERE pid=%s AND id=%s", (pid, int(file_id)), fetch="none")
    return bool(n)


def purge_expired_uploads() -> int:
    """Uploads are transient working data; outputs live as long as their thread."""
    ensure()
    if UPLOAD_TTL_DAYS <= 0:
        return 0
    cutoff = time.time() - UPLOAD_TTL_DAYS * 86400
    return int(_q(f"DELETE FROM `{T_FILE}` WHERE kind='upload' AND created<FROM_UNIXTIME(%s)",
                  (cutoff,), fetch="none") or 0)


def purge_orphans() -> int:
    """Delete conversations whose PacketFence person no longer exists.

    ON DELETE CASCADE normally handles this. But the foreign key to `person`
    must be dropped around a PacketFence schema upgrade (it blocks ALTER and
    DROP on person.pid), so this is the safety net that keeps the data correct
    while the constraint is absent."""
    ensure()
    total = 0
    for tbl in (T_THREAD, T_USAGE):
        try:
            total += int(_q(f"DELETE FROM `{tbl}` WHERE pid NOT IN (SELECT pid FROM person)",
                            fetch="none") or 0)
        except Exception as e:
            print(f"[pf-bot] orphan purge skipped for {tbl}: {e}")
    return total


def sweep_orphans(dry_run: bool = False) -> dict:
    """Delete blobs on disk that no row references any more.

    The database is authoritative, so this is safe to run at any time: rows are
    written before their blob is referenced, and a blob with no row can never be
    reached. This is the one lifecycle cost of spilling large files to disk —
    ON DELETE CASCADE removes the row but cannot remove the file."""
    ensure()
    if not os.path.isdir(FILE_DIR):
        return {"scanned": 0, "removed": 0, "bytes": 0}
    referenced = {r["sha256"] for r in
                  _q(f"SELECT DISTINCT sha256 FROM `{T_FILE}` WHERE disk_path IS NOT NULL")}
    scanned = removed = freed = 0
    for root, _dirs, files in os.walk(FILE_DIR):
        for fn in files:
            if fn.endswith(".tmp"):
                continue
            scanned += 1
            if fn in referenced:
                continue
            p = os.path.join(root, fn)
            try:
                sz = os.path.getsize(p)
                if not dry_run:
                    os.remove(p)
                removed += 1
                freed += sz
            except OSError:
                pass
    return {"scanned": scanned, "removed": removed, "bytes": freed, "dry_run": dry_run}


def quotas() -> dict:
    return {"inline_max": FILE_INLINE_MAX, "file_max": FILE_MAX,
            "thread_quota": FILE_THREAD_QUOTA, "user_quota": FILE_USER_QUOTA,
            "upload_ttl_days": UPLOAD_TTL_DAYS, "dir": FILE_DIR}
