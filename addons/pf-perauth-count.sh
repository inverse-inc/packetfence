#!/bin/bash
# pf-perauth-count.sh — measure SQL queries per RADIUS MAC auth on a PacketFence host.
#
# Wraps a user-initiated burst of auths between two MariaDB GLOBAL_STATUS snapshots,
# optionally captures a single-auth general_log trace, and reports per-auth deltas
# for Com_select / Com_insert / Com_update. Cross-checks the auth count against
# radius_audit_log (the ground truth Access-Accept counter on this build).
#
# Run on the PacketFence host (where mariadbd is reachable on its unix socket).
#
# Usage:
#   ./pf-perauth-count.sh                  # interactive — prompts before/after
#   ./pf-perauth-count.sh --trace          # also enable general_log for the window
#   ./pf-perauth-count.sh --trace --mycnf /root/.my.cnf
#
# Output goes to /tmp/pf-perauth-<timestamp>.log and the optional general_log
# trace to /var/lib/mysql/pf-perauth-trace-<timestamp>.log.

set -u

TRACE=0
MYCNF=""
# autodiscover a usable my.cnf so we don't need an interactive password
for c in /root/.my.cnf /etc/mysql/debian.cnf; do
    [ -r "$c" ] && MYCNF="$c" && break
done

while [ $# -gt 0 ]; do
    case "$1" in
        --trace)         TRACE=1; shift ;;
        --mycnf)         MYCNF="$2"; shift 2 ;;
        -h|--help)
            sed -n '1,/^set -u$/ p' "$0" | sed -n '/^#/p' | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUT="/tmp/pf-perauth-${RUN_ID}.log"
TRACE_LOG="/var/lib/mysql/pf-perauth-trace-${RUN_ID}.log"

exec > >(tee "$OUT") 2>&1

# ---------- mysql wrapper ----------
if [ -n "$MYCNF" ]; then
    MYSQL=(mysql --defaults-extra-file="$MYCNF" pf -BNe)
    echo "using credentials: $MYCNF"
else
    echo "no .my.cnf found — mysql will prompt for the pf user password."
    MYSQL=(mysql -p pf -BNe)
fi
q() { "${MYSQL[@]}" "$1"; }

# ---------- preflight ----------
echo "=== PF per-auth SQL count ${RUN_ID} ==="
if ! q "SELECT 1" >/dev/null 2>&1; then
    echo "ERROR: cannot reach mariadbd. Aborting."
    exit 1
fi
echo "MariaDB reachable."
echo

# ---------- snapshot helpers ----------
snap() {
    # snap LABEL -> echoes "LABEL <com_select> <com_insert> <com_update> <audit_count> <epoch>"
    local label="$1"
    local cs ci cu ac
    cs=$(q "SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Com_select'")
    ci=$(q "SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Com_insert'")
    cu=$(q "SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Com_update'")
    ac=$(q "SELECT COUNT(1) FROM radius_audit_log")
    echo "$label $cs $ci $cu $ac $(date +%s)"
}

# ---------- optional general_log enable ----------
if [ "$TRACE" -eq 1 ]; then
    echo "Enabling general_log to $TRACE_LOG ..."
    q "SET GLOBAL general_log_file = '$TRACE_LOG'" >/dev/null
    q "SET GLOBAL general_log = 1" >/dev/null
fi

# ---------- BEFORE ----------
BEFORE=$(snap before)
echo "BEFORE: $BEFORE"
echo
read -r _l _b_cs _b_ci _b_cu _b_ac _b_ts <<< "$BEFORE"

# ---------- prompt user ----------
echo
echo ">>> Fire your auth(s) NOW from your test client."
echo ">>> Press ENTER here once they're done."
echo "    (10-50 auths gives the cleanest signal vs. ~5/s background-query noise.)"
read -r _ </dev/tty

# ---------- AFTER ----------
AFTER=$(snap after)
echo "AFTER:  $AFTER"
read -r _l _a_cs _a_ci _a_cu _a_ac _a_ts <<< "$AFTER"

# ---------- optional general_log disable ----------
if [ "$TRACE" -eq 1 ]; then
    q "SET GLOBAL general_log = 0" >/dev/null
    echo "general_log captured to $TRACE_LOG"
fi

# ---------- compute ----------
ELAPSED=$((_a_ts - _b_ts))
[ "$ELAPSED" -lt 1 ] && ELAPSED=1
DELTA_CS=$((_a_cs - _b_cs))
DELTA_CI=$((_a_ci - _b_ci))
DELTA_CU=$((_a_cu - _b_cu))
DELTA_AC=$((_a_ac - _b_ac))

# rough background noise floor — observed ~5 Com_select/s from netdata + chi_cache polling
NOISE_PER_SEC=5
NOISE_TOTAL=$((ELAPSED * NOISE_PER_SEC))

AUTH_CS=$((DELTA_CS - NOISE_TOTAL))
[ "$AUTH_CS" -lt 0 ] && AUTH_CS=0

echo
echo "=== Results ==="
printf "elapsed seconds:              %d\n" "$ELAPSED"
printf "auths fired (audit_log delta):%d\n" "$DELTA_AC"
printf "Com_select total delta:       %d\n" "$DELTA_CS"
printf "Com_insert total delta:       %d\n" "$DELTA_CI"
printf "Com_update total delta:       %d\n" "$DELTA_CU"
printf "estimated background noise:   ~%d (%d/s × %ds)\n" "$NOISE_TOTAL" "$NOISE_PER_SEC" "$ELAPSED"
printf "estimated auth-attributable Com_select: %d\n" "$AUTH_CS"

if [ "$DELTA_AC" -gt 0 ]; then
    PER_AUTH_CS_RAW=$(( DELTA_CS / DELTA_AC ))
    PER_AUTH_CS_DENOISED=$(( AUTH_CS / DELTA_AC ))
    PER_AUTH_CI=$(( DELTA_CI / DELTA_AC ))
    PER_AUTH_CU=$(( DELTA_CU / DELTA_AC ))
    echo
    echo "per auth (raw):     ${PER_AUTH_CS_RAW} SELECT, ${PER_AUTH_CI} INSERT, ${PER_AUTH_CU} UPDATE"
    echo "per auth (denoise): ${PER_AUTH_CS_DENOISED} SELECT, ${PER_AUTH_CI} INSERT, ${PER_AUTH_CU} UPDATE"
    echo
    echo "Pre-patch baseline (from prior trace): ~34 SELECT + ~6 INSERT + ~3 UPDATE per auth."
    echo "Post-patch target (radius+role patch): ~30 SELECT + ~6 INSERT + ~3 UPDATE per auth."
else
    echo
    echo "WARN: audit_log delta is 0 — no auth was registered during the window."
    echo "Was the test client actually firing? Check radius.log on the PF host."
fi

# ---------- trace analysis ----------
if [ "$TRACE" -eq 1 ] && [ -r "$TRACE_LOG" ]; then
    echo
    echo "=== Single-auth trace summary ($TRACE_LOG) ==="

    # detect the most-mentioned MAC (the one from the auth)
    HOT_MAC=$(awk '
        match(tolower($0), /([0-9a-f]{2}:){5}[0-9a-f]{2}/) {
            mac = substr($0, RSTART, RLENGTH)
            c[mac]++
        }
        END { best=""; bestn=0; for (m in c) if (c[m]>bestn) { bestn=c[m]; best=m }
              if (best) printf "%s %d\n", best, bestn }
    ' "$TRACE_LOG")

    if [ -n "$HOT_MAC" ]; then
        MAC=$(echo "$HOT_MAC" | awk '{print $1}')
        COUNT=$(echo "$HOT_MAC" | awk '{print $2}')
        echo "Hottest MAC: $MAC  (mentioned in $COUNT log lines)"
        echo
        echo "Query shapes touching this MAC (top 20):"
        awk -v mac="$MAC" '
            tolower($0) ~ tolower(mac) {
                # strip MariaDB log prefix (timestamp/id/command) and capture the SQL after \t
                sub(/^[^Q]*Query[ \t]+/, "")
                sub(/^[^E]*Execute[ \t]+/, "")
                # normalize literals so equivalent queries group together
                gsub(/[0-9]+/, "?")
                gsub(/\047[^\047]*\047/, "?")
                gsub(/"[^"]*"/, "?")
                # trim
                gsub(/^[ \t]+|[ \t]+$/, "")
                if (length($0) > 160) $0 = substr($0, 1, 160) "..."
                print
            }
        ' "$TRACE_LOG" | sort | uniq -c | sort -rn | head -20
    else
        echo "No MAC-shaped strings found in trace — auth may not have fired during the window."
    fi
fi

echo
echo "=== Done. Report: $OUT ==="
[ "$TRACE" -eq 1 ] && echo "Raw trace: $TRACE_LOG"
