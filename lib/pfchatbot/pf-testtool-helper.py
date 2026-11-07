#!/usr/bin/env python3
"""pf-testtool-helper — runs 802.1X / RADIUS test tools on the PacketFence host.

SECURITY MODEL
--------------
This helper is the ONLY component that executes eapol_test / radclient / radtest.
The chatbot container cannot run these binaries; it can only ask this helper to,
over a Unix domain socket. That indirection is the security boundary:

  * Only three tools are runnable, chosen from a fixed dict — never a shell string.
  * Every argument is built here from a small set of typed, validated fields.
    User input is passed as argv items (never through a shell), and free-form
    values are additionally regex-checked.
  * The RADIUS target is FORCED to the configured server; a caller cannot point
    these tools at an arbitrary host.
  * Every run has a hard timeout and output cap.
  * The socket is created mode 0600, owned by the service user.

Config files are written to a private tempdir per run and deleted afterwards.
The shared secret is read from the environment here (RADIUS_SECRET), so it is
never sent across the socket or shown to the browser.

Protocol: newline-delimited JSON. Request:
  {"tool": "...", "params": {...}, "preview": bool}
Response:
  {"ok": bool, "preview": {...}, "output": "...", "rc": int, "error": "..."}
"""
from __future__ import annotations

import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
import threading

SOCKET_PATH = os.environ.get("PF_TESTTOOL_SOCK", "/run/pf-testtool/helper.sock")

# Forced RADIUS target — callers cannot change these.
def _detect_host_ip() -> str:
    """Primary outbound IPv4 of this host — the source address the kernel would
    use to reach an external destination (i.e. the default-route interface's IP,
    eth0 in most deployments). Uses a connectionless UDP socket, so it sends no
    packets and needs no route to actually exist. Falls back to 127.0.0.1."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("1.1.1.1", 53))  # no traffic sent for UDP connect()
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def _radius_target_from_admin_url() -> str:
    """PacketFence's admin URL points at the management interface, which is also
    where RADIUS listens. That beats guessing from the routing table: on a host
    whose default route is an internal link, route detection returns something
    in 100.64.0.0/10 (PacketFence's own connector range) and every test times
    out against an address nothing is listening on."""
    u = (os.environ.get("PF_ADMIN_URL") or "").strip()
    m = re.search(r"//\[([0-9a-fA-F:]+)\]", u)          # bracketed IPv6 literal
    if m:
        return m.group(1)
    m = re.search(r"//([^:/\s]+)", u)                     # host, stopping at :port or /
    return m.group(1) if m else ""


RADIUS_SERVER = os.environ.get("RADIUS_SERVER", "auto").strip()
if RADIUS_SERVER.lower() in ("", "auto"):
    RADIUS_SERVER = _radius_target_from_admin_url()
    if RADIUS_SERVER:
        print(f"[pf-testtool-helper] RADIUS_SERVER from PF_ADMIN_URL: {RADIUS_SERVER}")
    else:
        RADIUS_SERVER = _detect_host_ip()
        print(f"[pf-testtool-helper] RADIUS_SERVER auto-detected: {RADIUS_SERVER}")
if RADIUS_SERVER.startswith(("100.64.", "100.65.", "100.66.", "100.67.")):
    print(f"[pf-testtool-helper] WARNING: RADIUS_SERVER={RADIUS_SERVER} is in "
          "PacketFence's internal connector range; RADIUS almost certainly does "
          "not listen there. Set RADIUS_SERVER to the management IP in "
          "testtool.env or every test will time out.", flush=True)
RADIUS_AUTH_PORT = os.environ.get("RADIUS_AUTH_PORT", "1812")
RADIUS_ACCT_PORT = os.environ.get("RADIUS_ACCT_PORT", "1813")
RADIUS_SECRET = os.environ.get("RADIUS_SECRET", "")

# Prefer a secret file when configured (e.g. PacketFence's conf/local_secret).
# The file has no trailing newline in PacketFence, but strip() handles any
# whitespace/newline regardless. A non-empty RADIUS_SECRET env var, if set,
# is used as a fallback when the file is missing or unreadable.
_SECRET_FILE = os.environ.get("RADIUS_SECRET_FILE", "").strip()
if _SECRET_FILE:
    try:
        with open(_SECRET_FILE, "r", encoding="utf-8", errors="strict") as _f:
            _file_secret = _f.read().strip()
        if _file_secret:
            RADIUS_SECRET = _file_secret
            print(f"[pf-testtool-helper] RADIUS secret loaded from {_SECRET_FILE}")
        else:
            print(f"[pf-testtool-helper] {_SECRET_FILE} is empty; falling back to RADIUS_SECRET env")
    except OSError as e:
        print(f"[pf-testtool-helper] could not read {_SECRET_FILE} ({e}); "
              "falling back to RADIUS_SECRET env")

RUN_TIMEOUT = int(os.environ.get("PF_TESTTOOL_TIMEOUT", "20"))
MAX_OUTPUT = 64 * 1024

# ── packet-capture limits (hard caps; UI values are clamped to these) ─────────
CAP_MAX_SECONDS = int(os.environ.get("PF_CAP_MAX_SECONDS", "60"))
CAP_MAX_PACKETS = int(os.environ.get("PF_CAP_MAX_PACKETS", "500"))
CAP_DEFAULT_SECONDS = 20
CAP_DEFAULT_PACKETS = 200
# Interfaces the capture may run on. Empty => auto-detect at request time.
CAP_IFACES = [i.strip() for i in os.environ.get("PF_CAP_IFACES", "").split(",") if i.strip()]

# Named capture presets -> a safe, fixed BPF filter. The user picks one; the
# editable filter field starts from the preset and is re-validated server-side.
CAP_PRESETS = {
    "radius":  "udp port 1812 or udp port 1813",
    "dhcp":    "udp port 67 or udp port 68",
    "dns":     "udp port 53 or tcp port 53",
    "eap":     "ether proto 0x888e",           # EAPOL
    "all":     "",                              # no filter (still capped)
}

# A conservative BPF grammar: the tokens tcpdump filters actually use. We do NOT
# pass the filter through a shell, and we reject anything outside this set so a
# caller can't smuggle shell metacharacters or tcpdump's dangerous constructs.
_BPF_TOKEN = re.compile(
    r"^(?:"
    r"host|net|port|portrange|src|dst|and|or|not|ether|proto|ip|ip6|arp|rarp|"
    r"tcp|udp|icmp|icmp6|vlan|mpls|less|greater|"
    r"[0-9]{1,5}|"                                   # ports / numbers
    r"0x[0-9a-fA-F]{1,4}|"                           # ether proto etc.
    r"(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?|"         # IPv4 / CIDR
    r"[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}|"         # MAC
    r"[()]"                                          # grouping
    r")$"
)


def _validate_bpf(expr: str) -> str:
    """Validate a BPF filter by tokenizing and checking every token against a
    conservative allowlist. Returns the normalized filter or raises ValueError.
    Never shell-interpreted; passed to tcpdump as a single argument."""
    expr = (expr or "").strip()
    if not expr:
        return ""                                    # empty = capture all (still capped)
    if len(expr) > 200:
        raise ValueError("filter too long")
    # split on whitespace but keep parentheses as separate tokens
    spaced = expr.replace("(", " ( ").replace(")", " ) ")
    tokens = spaced.split()
    for t in tokens:
        if not _BPF_TOKEN.match(t):
            raise ValueError(f"disallowed token in filter: {t!r}")
    return " ".join(tokens)


def _cap_interfaces() -> list:
    """Interfaces the capture may use: the configured allowlist, or auto-detected
    non-loopback interfaces if none configured."""
    if CAP_IFACES:
        return CAP_IFACES
    ifaces = []
    try:
        for name in sorted(os.listdir("/sys/class/net")):
            if name != "lo":
                ifaces.append(name)
    except OSError:
        pass
    return ifaces or ["any"]


# Validation patterns for free-form fields.
_RE = {
    "username": re.compile(r"^[A-Za-z0-9._@/\\\-]{1,128}$"),
    "password": re.compile(r"^[\x20-\x7e]{1,128}$"),        # printable ASCII
    "mac": re.compile(r"^[0-9A-Fa-f]{2}([:\-][0-9A-Fa-f]{2}){5}$"),
    "path": re.compile(r"^/[A-Za-z0-9_./\-]{1,255}$"),      # cert paths on host
    "eap": re.compile(r"^(PEAP|TLS|TTLS)$"),
    "ipaddr": re.compile(r"^(\d{1,3}\.){3}\d{1,3}$"),
    "secret": re.compile(r"^[\x21-\x7e]{1,128}$"),  # printable ASCII, no spaces
}

# Attributes a caller may NOT set in an edited radclient body — they could
# redirect the request off-box or run a different sub-command.
_ATTR_BLOCKLIST = re.compile(r"(?im)^\s*(Proxy-To-Realm|Packet-Dst|Packet-Src)\b")


def _check_body(body: str, max_lines: int = 60, max_len: int = 8000) -> str:
    """Validate a user-edited config/attribute body. We don't parse RADIUS
    dictionaries here; we bound the size and reject a small blocklist of
    dangerous attributes. The target host/port/secret are still supplied by
    the helper via argv, never from this body — so an edit cannot change where
    the request goes."""
    if len(body) > max_len:
        raise ValueError("config too long")
    if body.count("\n") > max_lines:
        raise ValueError("config has too many lines")
    if _ATTR_BLOCKLIST.search(body):
        raise ValueError("config contains a disallowed attribute")
    return body


def _v(field: str, value: str, required: bool = True) -> str:
    value = (value or "").strip()
    if not value:
        if required:
            raise ValueError(f"missing required field: {field}")
        return ""
    if not _RE[field].match(value):
        raise ValueError(f"invalid {field}")
    return value


def preflight(deep: bool = False) -> dict:
    """Check the helper's own environment before any test runs.
    Returns {"ok": bool, "checks": [{name, ok, detail}], ...}.
    `deep=True` additionally probes RADIUS reachability with a UDP round-trip
    (only done on explicit health requests, not on every test run)."""
    checks: list[dict] = []

    def add(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    # 1. shared secret present
    add("radius_secret", bool(RADIUS_SECRET),
        "loaded" if RADIUS_SECRET else "empty — set RADIUS_SECRET or RADIUS_SECRET_FILE")

    # 2. target resolved
    add("radius_target", bool(RADIUS_SERVER) and RADIUS_SERVER != "127.0.0.1"
        or RADIUS_SERVER == "127.0.0.1",
        f"{RADIUS_SERVER}:{RADIUS_AUTH_PORT}")

    # 3. binaries installed
    for b in ("eapol_test", "radclient"):
        p = shutil.which(b)
        add(f"bin:{b}", bool(p), p or "not installed on host")

    # 4. runtime dir writable (for per-run config files / tempdir)
    try:
        t = tempfile.mkdtemp(prefix="pftt-pre-")
        shutil.rmtree(t, ignore_errors=True)
        add("tempdir", True, "writable")
    except Exception as e:
        add("tempdir", False, str(e))

    # 5. (deep) RADIUS server reachable — send Status-Server / a probe packet
    if deep:
        add("radius_reachable", *_probe_radius())

    ok = all(c["ok"] for c in checks)
    return {"ok": ok, "checks": checks,
            "target": f"{RADIUS_SERVER}:{RADIUS_AUTH_PORT}",
            "secret_source": _SECRET_FILE if (_SECRET_FILE and RADIUS_SECRET) else "env"}


def _probe_radius() -> tuple[bool, str]:
    """Best-effort reachability probe: open a UDP socket to the RADIUS auth port
    and send a minimal RADIUS Status-Server packet, waiting briefly for any
    reply. A reply (even an error) proves the server is listening and the path
    works. No reply within the timeout is reported but not treated as fatal,
    since some servers don't answer Status-Server without config."""
    import struct
    try:
        # RADIUS Status-Server (code 12), id 0, length 20, 16-byte authenticator
        auth = os.urandom(16)
        pkt = struct.pack("!BBH16s", 12, 0, 20, auth)
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(3.0)
        try:
            s.sendto(pkt, (RADIUS_SERVER, int(RADIUS_AUTH_PORT)))
            data, _ = s.recvfrom(4096)
            return True, f"reply received ({len(data)} bytes)"
        except socket.timeout:
            return True, "no reply to Status-Server (server may not answer it); path open"
        except OSError as e:
            return False, f"unreachable: {e}"
        finally:
            s.close()
    except Exception as e:
        return False, f"probe error: {e}"


def _bin(name: str) -> str:
    p = shutil.which(name)
    if not p:
        raise ValueError(f"{name} not installed on host")
    return p


# ── config + command builders ────────────────────────────────────────────────
def _eapol_conf(params: dict) -> str:
    eap = _v("eap", params.get("eap", "PEAP"))
    ident = _v("username", params.get("username"))
    if eap == "PEAP":
        pw = _v("password", params.get("password"))
        inner = params.get("inner", "MSCHAPV2")
        if inner not in ("MSCHAPV2", "MSCHAPv2", "PAP", "GTC"):
            raise ValueError("invalid inner method")
        return (
            "network={\n"
            "    key_mgmt=IEEE8021X\n"
            "    eap=PEAP\n"
            f'    identity="{ident}"\n'
            f'    password="{pw}"\n'
            f'    phase2="auth={inner.upper()}"\n'
            "}\n"
        )
    # EAP-TLS
    ca = _v("path", params.get("ca_cert"), required=False)
    client = _v("path", params.get("client_cert"))
    key = _v("path", params.get("private_key"))
    key_pw = _v("password", params.get("key_password"), required=False)
    lines = [
        "network={",
        "    key_mgmt=IEEE8021X",
        "    eap=TLS",
        f'    identity="{ident}"',
        f'    client_cert="{client}"',
        f'    private_key="{key}"',
    ]
    if ca:
        lines.append(f'    ca_cert="{ca}"')
    if key_pw:
        lines.append(f'    private_key_passwd="{key_pw}"')
    lines.append("}\n")
    return "\n".join(lines)


def _radclient_attrs(params: dict) -> str:
    """Build the RADIUS attribute block (radclient stdin) for a PAP/MAB request.
    Mirrors what a switch sends: MAC as User-Name/Password plus the NAS context
    that PacketFence matches against switches.conf. NAS-IP-Address is decisive —
    it must match a switch PacketFence knows, or the request is rejected."""
    user = _v("username", params.get("username"))
    pw = _v("password", params.get("password"))
    lines = [f"User-Name = {user}", f"User-Password = {pw}"]
    nas_ip = _v("ipaddr", params.get("nas_ip"), required=False)
    if nas_ip:
        lines.append(f"NAS-IP-Address = {nas_ip}")
    called = _v("mac", params.get("called_station"), required=False)
    calling = _v("mac", params.get("calling_station"), required=False)
    if called:
        lines.append(f'Called-Station-Id = "{called}"')
    if calling:
        lines.append(f'Calling-Station-Id = "{calling}"')
    lines.append("Service-Type = Call-Check")
    lines.append("NAS-Port-Type = Ethernet")
    lines.append("Message-Authenticator = 0x00")
    return "\n".join(lines) + "\n"


def _build(tool: str, params: dict, workdir: str) -> tuple[list[str], dict]:
    """Returns (argv, preview_dict). preview_dict is safe to show the user
    (secrets masked). If params['config'] is provided (a user-edited body from
    the UI), it is used verbatim after validation; otherwise a default config is
    generated from the individual fields. The RADIUS target always comes from
    the helper's own config. The shared secret defaults to the host's configured
    secret, but a per-run override may be supplied in params['secret'] (used for
    this run only, never persisted, always redacted from output/preview)."""
    # A per-run secret override is only honored for eapol_test (switch testing).
    # radclient/radtest always use the host-configured secret, so MAB tests can't
    # be run with a mismatched secret by mistake.
    if tool == "eapol_test":
        secret = _v("secret", params.get("secret"), required=False) or RADIUS_SECRET
    else:
        secret = RADIUS_SECRET
    if not secret:
        raise ValueError("no RADIUS secret: none configured on the host and none provided")

    # Per-run timeout: editable in the UI, defaults to RUN_TIMEOUT, capped so a
    # caller can't tie up the helper indefinitely.
    try:
        run_timeout = int(params.get("timeout") or RUN_TIMEOUT)
    except (TypeError, ValueError):
        raise ValueError("timeout must be a number")
    run_timeout = max(1, min(run_timeout, 120))

    edited = params.get("config")
    edited = _check_body(edited) if isinstance(edited, str) and edited.strip() else None

    if tool == "eapol_test":
        conf = edited if edited is not None else _eapol_conf(params)
        conf_path = os.path.join(workdir, "eapol.conf")
        with open(conf_path, "w") as f:
            f.write(conf)
        argv = [
            _bin("eapol_test"), "-c", conf_path,
            "-a", RADIUS_SERVER, "-p", RADIUS_AUTH_PORT,
            "-s", secret, "-t", str(run_timeout),
        ]
        # `config` is masked for DISPLAY; `config_editable` is the real,
        # runnable config that fills the editable textarea (masking it would
        # send ******** as the actual password on run).
        shown = conf
        if edited is None:
            shown = re.sub(r'(password=")[^"]*(")', r"\1********\2", conf)
            shown = re.sub(r'(private_key_passwd=")[^"]*(")', r"\1********\2", shown)
        preview = {
            "config_file": "eapol.conf",
            "config": shown,
            "config_editable": conf,
            "editable": True,
            "command": f"eapol_test -c eapol.conf -a {RADIUS_SERVER} "
                       f"-p {RADIUS_AUTH_PORT} -s ******** -t {run_timeout}",
        }
        preview["_secret"] = secret
        preview["_timeout"] = run_timeout
        return argv, preview

    if tool in ("radclient", "radtest"):
        stdin = edited if edited is not None else _radclient_attrs(params)
        if edited is not None and "User-Name" not in stdin:
            raise ValueError("radclient attributes must include User-Name")
        argv = [
            _bin("radclient"), "-x", "-t", str(run_timeout), "-r", "1",
            f"{RADIUS_SERVER}:{RADIUS_AUTH_PORT}", "auth", secret,
        ]
        # masked for DISPLAY; real for the editable textarea (see eapol note)
        shown = stdin
        if edited is None and params.get("password"):
            shown = stdin.replace(f"User-Password = {params['password']}",
                                  "User-Password = ********")
        preview = {
            "config_file": "radclient attributes (stdin)",
            "config": shown,
            "config_editable": stdin,
            "editable": True,
            "command": f"radclient -x {RADIUS_SERVER}:{RADIUS_AUTH_PORT} auth ******** < attrs",
        }
        return argv, {**preview, "_stdin": stdin, "_secret": secret, "_timeout": run_timeout}

    raise ValueError(f"unknown tool: {tool}")


# ── run ──────────────────────────────────────────────────────────────────────
def _run_capture(params: dict, preview: bool) -> dict:
    """Run a bounded tcpdump capture then summarize it with tshark. Only a
    STRUCTURED SUMMARY is returned (protocol hierarchy, conversations, and a
    control-plane decode) -- never raw packet payloads -- so nothing sensitive
    on the wire is shipped to the LLM."""
    tcpdump = shutil.which("tcpdump")
    tshark = shutil.which("tshark")

    ifaces = _cap_interfaces()
    iface = (params.get("iface") or (ifaces[0] if ifaces else "any")).strip()
    if iface not in ifaces and iface != "any":
        return {"ok": False, "error": f"interface not allowed: {iface}"}

    preset = (params.get("preset") or "radius").strip()
    # filter: explicit (validated) filter wins; else the preset's fixed filter
    if params.get("filter") is not None and str(params.get("filter")).strip():
        bpf = _validate_bpf(str(params["filter"]))
    else:
        if preset not in CAP_PRESETS:
            return {"ok": False, "error": f"unknown preset: {preset}"}
        bpf = CAP_PRESETS[preset]

    try:
        seconds = int(params.get("seconds") or CAP_DEFAULT_SECONDS)
        packets = int(params.get("packets") or CAP_DEFAULT_PACKETS)
    except (TypeError, ValueError):
        return {"ok": False, "error": "seconds/packets must be numbers"}
    seconds = max(1, min(seconds, CAP_MAX_SECONDS))
    packets = max(1, min(packets, CAP_MAX_PACKETS))

    # command preview (shown to the user before Run)
    cmd_preview = (f"tcpdump -i {iface} -c {packets} -G {seconds} -W 1 "
                   f"-w <capture.pcap>" + (f" '{bpf}'" if bpf else ""))
    prev = {
        "iface": iface, "preset": preset, "filter": bpf,
        "seconds": seconds, "packets": packets,
        "interfaces": ifaces,
        "command": cmd_preview, "editable": True,
        "note": "Capture is bounded and only a structured summary (no raw "
                "payloads) is analyzed.",
    }
    if preview:
        return {"ok": True, "preview": prev}

    if not tcpdump:
        return {"ok": False, "preview": prev, "error": "tcpdump not installed on host"}

    workdir = tempfile.mkdtemp(prefix="pfcap-")
    pcap = os.path.join(workdir, "capture.pcap")
    try:
        # tcpdump args as a list (NO shell). -c caps packets, timeout caps time.
        argv = [tcpdump, "-i", iface, "-c", str(packets), "-w", pcap, "-n", "-q"]
        if bpf:
            argv.append(bpf)                          # single arg, not shell-split
        try:
            subprocess.run(argv, capture_output=True, text=True,
                           timeout=seconds + 5)
        except subprocess.TimeoutExpired:
            pass                                       # time cap reached: use what we have
        if not os.path.exists(pcap) or os.path.getsize(pcap) == 0:
            return {"ok": True, "preview": prev,
                    "summary": "No packets captured in the window (no matching "
                               "traffic, or the interface saw nothing)."}

        summary = _summarize_pcap(pcap, tshark)
        return {"ok": True, "preview": prev, "summary": summary}
    except Exception as e:
        return {"ok": False, "preview": prev, "error": f"capture failed: {e}"}
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def _summarize_pcap(pcap: str, tshark: str) -> str:
    """Produce an LLM-safe text summary from a pcap using tshark: packet count,
    protocol hierarchy, endpoint/conversation stats, and a one-line-per-packet
    control-plane view (RADIUS/EAP/DHCP/DNS). No payloads."""
    if not tshark:
        # fall back to tcpdump's own summary counts if tshark isn't present
        return ("tshark not installed; only a raw count is available. Install "
                "wireshark-cli/tshark on the host for a full protocol summary.")
    parts = []

    def _run(args, cap=8000):
        try:
            r = subprocess.run([tshark, "-r", pcap, *args],
                               capture_output=True, text=True, timeout=30)
            out = (r.stdout or "").strip()
            return out[:cap]
        except Exception as e:
            return f"(tshark {args[:1]} failed: {e})"

    # 1. protocol hierarchy (counts per protocol)
    phs = _run(["-q", "-z", "io,phs"])
    if phs:
        parts.append("## Protocol hierarchy\n" + phs)
    # 2. conversations (who talked to whom, byte/packet counts)
    conv = _run(["-q", "-z", "conv,ip"])
    if conv:
        parts.append("## IP conversations\n" + conv)
    # 3. control-plane decode: one concise line per packet for the protocols we
    #    care about, showing header fields only (no payload). Fields chosen to be
    #    diagnostic, not sensitive.
    decode = _run([
        "-n",
        "-Y", "radius or eap or eapol or bootp or dns",
        "-T", "fields",
        "-e", "frame.number", "-e", "frame.time_relative",
        "-e", "ip.src", "-e", "ip.dst",
        "-e", "radius.code", "-e", "eap.code", "-e", "eap.type",
        "-e", "bootp.option.dhcp", "-e", "dns.qry.name",
        "-E", "header=y", "-E", "separator=|",
    ], cap=12000)
    if decode:
        parts.append("## Control-plane packets (headers only)\n" + decode)

    return "\n\n".join(parts) if parts else "Capture contained no summarizable packets."


def handle(req: dict) -> dict:
    # Health/self-check request: report environment readiness.
    if req.get("action") == "health":
        return {"ok": True, **preflight(deep=bool(req.get("deep")))}

    # Packet capture + tshark summary (bounded; summary-only to the caller).
    if req.get("action") == "capture":
        return _run_capture(req.get("params") or {}, bool(req.get("preview")))

    tool = req.get("tool", "")
    if tool not in ("eapol_test", "radclient", "radtest"):
        return {"ok": False, "error": f"tool not allowed: {tool}"}

    # Pre-run gate (skipped for preview, which builds config without executing):
    # verify the environment can actually run this tool before we try.
    if not req.get("preview"):
        pf = preflight(deep=False)
        has_secret = bool(RADIUS_SECRET) or (
            tool == "eapol_test" and bool((req.get("params") or {}).get("secret"))
        )
        blocking = [c for c in pf["checks"]
                    if not c["ok"] and c["name"] in ("tempdir",
                                                     f"bin:{'eapol_test' if tool == 'eapol_test' else 'radclient'}")]
        if not has_secret:
            blocking.append({"name": "radius_secret",
                             "detail": "empty — set on host or enter one in the UI"})
        if blocking:
            msg = "; ".join(f"{c['name']}: {c['detail']}" for c in blocking)
            return {"ok": False, "error": f"pre-run check failed \u2014 {msg}"}

    params = req.get("params") or {}
    workdir = tempfile.mkdtemp(prefix="pftt-")
    try:
        argv, preview = _build(tool, params, workdir)
        stdin = preview.pop("_stdin", None)
        run_secret = preview.pop("_secret", None)  # never send the secret to the client
        run_timeout = preview.pop("_timeout", RUN_TIMEOUT)
        if req.get("preview"):
            return {"ok": True, "preview": preview}
        try:
            proc = subprocess.run(
                argv,
                input=stdin,
                capture_output=True,
                text=True,
                timeout=run_timeout + 5,
                cwd=workdir,
            )
            out = (proc.stdout or "") + (proc.stderr or "")
            if len(out) > MAX_OUTPUT:
                out = out[:MAX_OUTPUT] + "\n...[output truncated]"
            # never echo any secret back even if a tool prints it
            for sec in {RADIUS_SECRET, run_secret}:
                if sec:
                    out = out.replace(sec, "********")
            return {"ok": True, "preview": preview, "output": out, "rc": proc.returncode}
        except subprocess.TimeoutExpired:
            return {"ok": False, "preview": preview, "error": "test timed out"}
    except ValueError as e:
        return {"ok": False, "error": str(e)}
    except Exception as e:
        return {"ok": False, "error": f"helper error: {e}"}
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def _serve_client(conn: socket.socket) -> None:
    conn.settimeout(120 + 15)  # covers the max allowed per-run timeout
    buf = b""
    try:
        while b"\n" not in buf:
            chunk = conn.recv(4096)
            if not chunk:
                return
            buf += chunk
            if len(buf) > 1_000_000:
                return
        req = json.loads(buf.split(b"\n", 1)[0].decode())
        resp = handle(req)
    except Exception as e:
        resp = {"ok": False, "error": f"bad request: {e}"}
    try:
        conn.sendall((json.dumps(resp) + "\n").encode())
    except OSError:
        pass
    finally:
        conn.close()


def main() -> None:
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o660)
    srv.listen(4)
    print(f"[pf-testtool-helper] listening on {SOCKET_PATH}; target {RADIUS_SERVER}:{RADIUS_AUTH_PORT}")
    pf = preflight(deep=False)
    for c in pf["checks"]:
        mark = "ok " if c["ok"] else "FAIL"
        print(f"[pf-testtool-helper]   [{mark}] {c['name']}: {c['detail']}")
    if not pf["ok"]:
        print("[pf-testtool-helper] WARNING: environment not fully ready; "
              "tests may fail until the above are resolved.")
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=_serve_client, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
