#!/bin/bash
# pf-perf-probe.sh — observe PacketFence during a RADIUS auth load test.
#
# Run this on the PacketFence host (as root).
# Start it just before kicking off your load generator.
#
# Usage:
#   ./pf-perf-probe.sh [duration_seconds]
#
# Defaults to 60 seconds. Output goes to /tmp/pf-perf-<timestamp>.log.

set -u

DURATION="${1:-60}"
SAMPLE=5
RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUT="/tmp/pf-perf-${RUN_ID}.log"
PIDSTAT_RAW="/tmp/pf-perf-${RUN_ID}.pidstat"

QSOCK=/usr/local/pf/var/run/redis_queue.sock
RLOG=/usr/local/pf/logs/radius.log
PF_CONF=/usr/local/pf/conf/pf.conf
PFQ_CONF=/usr/local/pf/conf/pfqueue.conf
MYCNF_CANDIDATES=(/root/.my.cnf /etc/mysql/debian.cnf)

# everything below also goes to the report file
exec > >(tee "$OUT") 2>&1

echo "=== PF perf probe ${RUN_ID} ==="
echo "duration: ${DURATION}s   sample interval: ${SAMPLE}s"
echo "report:   ${OUT}"
echo

# ---------- config snapshot ----------
echo "--- Config ---"
grep '^pfperl_api_processes' "$PF_CONF" 2>/dev/null || echo "pfperl_api_processes: <default>"
echo "[queue general]"
awk '/^\[queue general\]/{flag=1; next} /^\[/{flag=0} flag && /^[a-z]/{print "  "$0}' "$PFQ_CONF" 2>/dev/null
echo
echo "general workers running: $(pgrep -fc 'pfqueue.*Queue:general' || echo 0)"
echo "pfperl-api workers:      $(pgrep -fc 'pfperl-api prefork' || echo 0)"
echo

# ---------- baseline ----------
echo "--- Baseline ---"
uptime
echo

# ---------- start pidstat in background ----------
N_SAMPLES=$(( DURATION / SAMPLE ))
pidstat -u "$SAMPLE" "$N_SAMPLES" > "$PIDSTAT_RAW" 2>&1 &
PSPID=$!

# baseline counters
N1=$( { grep -cE 'Sent Access-Accept' "$RLOG" 2>/dev/null || true; } | head -1)
[ -z "$N1" ] && N1=0
T1=$(date +%s)

# ---------- live sampling ----------
echo "--- Live samples ---"
printf "%-7s %-12s %-30s\n" "t" "Q:general" "load avg (1/5/15)"
elapsed=0
while [ "$elapsed" -lt "$DURATION" ]; do
    g=$(redis-cli -s "$QSOCK" LLEN Queue:general 2>/dev/null)
    l=$(awk '{print $1, $2, $3}' /proc/loadavg)
    printf "%-7s %-12s %-30s\n" "${elapsed}s" "${g:-?}" "$l"
    sleep "$SAMPLE"
    elapsed=$(( elapsed + SAMPLE ))
done

wait "$PSPID" 2>/dev/null || true

# ---------- compute auth rate ----------
N2=$( { grep -cE 'Sent Access-Accept' "$RLOG" 2>/dev/null || true; } | head -1)
[ -z "$N2" ] && N2=0
T2=$(date +%s)
DUR=$(( T2 - T1 ))
[ "$DUR" -lt 1 ] && DUR=1
ACCEPTS=$(( N2 - N1 ))
RATE=$(( ACCEPTS / DUR ))

echo
echo "--- Result ---"
printf "duration:        %ss\n" "$DUR"
printf "Access-Accept:   %s\n" "$ACCEPTS"
printf "auth/sec:        %s\n" "$RATE"
echo

# ---------- pidstat filtered ----------
echo "--- pidstat (filtered to PF/DB/Redis) ---"
awk 'NR<=3 || /pfperl-api|mariadbd|redis|pfqueue|pfacct|radiusd/' "$PIDSTAT_RAW"
echo

# ---------- final queue depths ----------
echo "--- Final queue depths ---"
redis-cli -s "$QSOCK" KEYS 'Queue:*' 2>/dev/null | sort | while read -r q; do
    [ -n "$q" ] || continue
    printf "  %6s  %s\n" "$(redis-cli -s "$QSOCK" LLEN "$q" 2>/dev/null)" "$q"
done
echo

# ---------- audit_log buckets (best-effort, needs mysql access) ----------
MYCNF=""
for c in "${MYCNF_CANDIDATES[@]}"; do
    [ -r "$c" ] && MYCNF="$c" && break
done
if [ -n "$MYCNF" ]; then
    echo "--- radius_audit_log buckets (last 5 min) ---"
    mysql --defaults-extra-file="$MYCNF" pf -N -B -e \
      "SELECT COUNT(1), created_at FROM radius_audit_log
       WHERE created_at >= NOW() - INTERVAL 5 MINUTE
       GROUP BY created_at ORDER BY created_at DESC LIMIT 30;" 2>/dev/null \
      | awk '{printf "  %6s  %s %s\n", $1, $2, $3}'
    echo
else
    echo "--- audit_log buckets: skipped (no usable my.cnf found) ---"
    echo "Run manually:"
    echo "  mysql -p pf -e \"SELECT COUNT(1), created_at FROM radius_audit_log WHERE created_at >= NOW() - INTERVAL 5 MINUTE GROUP BY created_at ORDER BY created_at DESC LIMIT 30;\""
    echo
fi

echo "=== Done ==="
echo "Report:        ${OUT}"
echo "Pidstat raw:   ${PIDSTAT_RAW}"
