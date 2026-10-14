#!/usr/bin/env bash
#
# fetch-pf-docs.sh — download the PacketFence guides matching the installed
# version into the chatbot's docs dir, for the RAG corpus.
#
# Strategy:
#   1. Detect the installed PF version (fast: read conf/pf-release).
#   2. Try the version-matched HTML docs at /doc/<version>/  (exact match).
#   3. Fall back to the latest PDFs at /downloads/.../*.pdf if HTML 404s.
#   HTML is converted to clean text at download time so the RAG indexes prose,
#   not markup. PDFs are saved as-is (the RAG reads them via pypdf).
#
# Usage:
#   sudo ./fetch-pf-docs.sh                 # auto-detect version -> docs dir
#   sudo ./fetch-pf-docs.sh 15.1.0          # force a version
#   DOCS_DIR=/tmp/d ./fetch-pf-docs.sh      # override output dir
#
set -euo pipefail

DOCS_DIR="${DOCS_DIR:-/usr/local/pf/containers/pfchatbot/docs}"
PF_RELEASE="${PF_RELEASE:-/usr/local/pf/conf/pf-release}"
BASE_HTML="https://packetfence.org/doc"
BASE_PDF="https://packetfence.org/downloads/PacketFence/doc"

GUIDES=(
  PacketFence_Installation_Guide
  PacketFence_Upgrade_Guide
  PacketFence_Network_Devices_Configuration_Guide
  PacketFence_Clustering_Guide
)

log()  { printf '\033[1;33m[pf-docs]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;35m[pf-docs] WARN:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[pf-docs] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required"

# ── 1. determine version ──────────────────────────────────────────────────
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  if [ -r "$PF_RELEASE" ]; then
    # file looks like: "PacketFence 15.1.0"
    VERSION="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$PF_RELEASE" | head -1 || true)"
    [ -n "$VERSION" ] && log "detected version $VERSION (from $PF_RELEASE)"
  fi
fi
if [ -z "$VERSION" ]; then
  # fallback: package manager
  if command -v rpm >/dev/null && rpm -q packetfence >/dev/null 2>&1; then
    VERSION="$(rpm -q --qf '%{VERSION}' packetfence | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  elif command -v dpkg-query >/dev/null; then
    VERSION="$(dpkg-query -W -f='${Version}' packetfence 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  fi
  [ -n "$VERSION" ] && log "detected version $VERSION (from package manager)"
fi
if [ -z "$VERSION" ]; then
  warn "could not detect PF version; will use the latest PDFs"
fi

mkdir -p "$DOCS_DIR"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── html -> text (uses python3, always present on a PF host; mirrors the
#    RAG's own _strip_html so indexed text matches what the app would produce) ─
html_to_text() {
  # $1 = input html file, $2 = output text file
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
html = open(sys.argv[1], encoding="utf-8", errors="replace").read()
html = re.sub(r"<(script|style)\b.*?</\1>", " ", html, flags=re.I | re.S)
html = re.sub(r"</(p|div|li|h[1-6]|tr|section|article)>", "\n\n", html, flags=re.I)
text = re.sub(r"<[^>]+>", " ", html)
for a, b in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
             ("&quot;", '"'), ("&#39;", "'")]:
    text = text.replace(a, b)
text = re.sub(r"[ \t]+", " ", text)
text = re.sub(r"\n{3,}", "\n\n", text)
open(sys.argv[2], "w", encoding="utf-8").write(text)
PYEOF
}

fetch_html() {  # $1 guide -> writes $DOCS_DIR/$1.txt ; returns 0 on success
  local g="$1" url="$BASE_HTML/$VERSION/$g.html" out="$DOCS_DIR/$g.txt"
  local code
  code="$(curl -s -o "$TMP/$g.html" -w '%{http_code}' -L --max-time 60 "$url" || echo 000)"
  if [ "$code" = "200" ] && [ -s "$TMP/$g.html" ]; then
    html_to_text "$TMP/$g.html" "$out"
    if [ -s "$out" ]; then log "  \u2713 $g  (HTML v$VERSION -> $(wc -l <"$out") lines)"; return 0; fi
  fi
  return 1
}

fetch_pdf() {  # $1 guide -> writes $DOCS_DIR/$1.pdf ; returns 0 on success
  local g="$1" url="$BASE_PDF/$g.pdf" out="$DOCS_DIR/$g.pdf"
  local code
  code="$(curl -s -o "$out" -w '%{http_code}' -L --max-time 120 "$url" || echo 000)"
  if [ "$code" = "200" ] && [ -s "$out" ]; then
    log "  ✓ $g  (PDF latest -> $(du -h "$out" | cut -f1))"; return 0
  fi
  rm -f "$out"; return 1
}

# ── 2/3. fetch each guide: versioned HTML first, then latest PDF ───────────
log "writing docs to $DOCS_DIR"
ok=0; fail=0
for g in "${GUIDES[@]}"; do
  # clear any prior copy of this guide (either extension)
  rm -f "$DOCS_DIR/$g.txt" "$DOCS_DIR/$g.pdf"
  if [ -n "$VERSION" ] && fetch_html "$g"; then ok=$((ok+1)); continue; fi
  if fetch_pdf "$g"; then ok=$((ok+1)); else warn "  ✗ $g — could not fetch HTML or PDF"; fail=$((fail+1)); fi
done

# ── report + RAG hint ──────────────────────────────────────────────────────
echo
log "done: $ok fetched, $fail failed, in $DOCS_DIR"
ls -1 "$DOCS_DIR" | sed 's/^/  /'
echo
log "the RAG indexes everything in the docs dir by default \u2014 no .env change needed."
log "(it is mounted into the container at /docs.) rebuild the corpus with:"
log "    systemctl restart pf-chatbot"
