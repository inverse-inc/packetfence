#!/bin/bash
# pf-redis-probe.sh — observe both PacketFence Redis instances during load.
#
# Run on the PacketFence host (as root).
# Usage:
#   ./pf-redis-probe.sh [duration_seconds]
#
# Default 60s. Output: /tmp/pf-redis-<timestamp>.log
#
# Two instances are monitored:
#   cache  — /usr/local/pf/var/run/redis_cache.sock  (CHI/pfconfig — single thread, often the wall)
#   queue  — /usr/local/pf/var/run/redis_queue.sock  (pfqueue tasks)

set -u

DURATION="${1:-60}"
SAMPLE=5
RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUT="/tmp/pf-redis-${RUN_ID}.log"

CACHE_SOCK=/usr/local/pf/var/run/redis_cache.sock
QUEUE_SOCK=/usr/local/pf/var/run/redis_queue.sock

exec > >(tee "$OUT") 2>&1

# helpers ---------------------------------------------------------------------
rcli() { redis-cli -s "$1" "${@:2}"; }

info_field() {
    # rcli SOCK INFO SECTION FIELD  ->  prints just the value
    local sock="$1" section="$2" field="$3"
    rcli "$sock" INFO "$section" 2>/dev/null | awk -F: -v k="$field" '$1==k{gsub(/\r/,"",$2); print $2}'
}

snapshot_header() {
    local label="$1" sock="$2"
    echo "------ $label ($sock) ------"
    if ! rcli "$sock" PING >/dev/null 2>&1; then
        echo "  (unreachable)"
        return 1
    fi
    printf "  redis_version:        %s\n" "$(info_field "$sock" server redis_version)"
    printf "  process_id:           %s\n" "$(info_field "$sock" server process_id)"
    printf "  connected_clients:    %s\n" "$(info_field "$sock" clients connected_clients)"
    printf "  used_memory_human:    %s\n" "$(info_field "$sock" memory used_memory_human)"
    printf "  total_keys (db0):     $(rcli "$sock" DBSIZE 2>/dev/null)\n"
    printf "  total_commands:       %s\n" "$(info_field "$sock" stats total_commands_processed)"
    printf "  ops/sec (instant):    %s\n" "$(info_field "$sock" stats instantaneous_ops_per_sec)"
}

reset_stats() {
    local sock="$1"
    rcli "$sock" CONFIG RESETSTAT >/dev/null 2>&1 || true
    rcli "$sock" CONFIG SET slowlog-log-slower-than 1000 >/dev/null 2>&1 || true   # 1ms
    rcli "$sock" CONFIG SET slowlog-max-len 128 >/dev/null 2>&1 || true
    rcli "$sock" SLOWLOG RESET >/dev/null 2>&1 || true
    rcli "$sock" LATENCY RESET >/dev/null 2>&1 || true
    rcli "$sock" CONFIG SET latency-monitor-threshold 50 >/dev/null 2>&1 || true   # 50ms
}

print_commandstats() {
    local label="$1" sock="$2"
    echo
    echo "------ $label commandstats (top 15 by total time) ------"
    rcli "$sock" INFO commandstats 2>/dev/null \
      | awk -F'[:,=]' '
            /^cmdstat_/{
              cmd=$1; gsub(/^cmdstat_/,"",cmd)
              calls=$3; usec=$5; upc=$7
              printf "%-20s calls=%-10s usec=%-12s usec/call=%s\n", cmd, calls, usec, upc
            }' \
      | sort -t'=' -k3,3 -nr -k2.7 \
      | head -15
}

print_slowlog() {
    local label="$1" sock="$2"
    echo
    echo "------ $label slowlog (>1ms, last 10) ------"
    rcli "$sock" SLOWLOG GET 10 2>/dev/null \
      | awk 'BEGIN{n=0} /^[0-9]+$/{n++} {print n": "$0}' \
      | head -80
}

print_latency() {
    local label="$1" sock="$2"
    echo
    echo "------ $label latency events ------"
    rcli "$sock" LATENCY LATEST 2>/dev/null || echo "  (none)"
}

# ----------------------------------------------------------------------------- main

echo "=== PF redis probe ${RUN_ID} ==="
echo "duration: ${DURATION}s   sample interval: ${SAMPLE}s"
echo "report:   ${OUT}"
echo

echo "--- Baseline ---"
snapshot_header "cache" "$CACHE_SOCK" || true
snapshot_header "queue" "$QUEUE_SOCK" || true
echo

echo "--- Resetting stats / slowlog / latency ---"
reset_stats "$CACHE_SOCK"
reset_stats "$QUEUE_SOCK"
echo "done."
echo

# Live samples
echo "--- Live samples ---"
printf "%-7s %-12s %-12s %-12s %-12s %-12s %-12s\n" \
       "t" "cache_ops" "cache_clnt" "cache_mem" "queue_ops" "queue_clnt" "Q:general"
elapsed=0
while [ "$elapsed" -lt "$DURATION" ]; do
    cache_ops=$(info_field "$CACHE_SOCK" stats instantaneous_ops_per_sec)
    cache_cl=$(info_field "$CACHE_SOCK" clients connected_clients)
    cache_mem=$(info_field "$CACHE_SOCK" memory used_memory_human)
    queue_ops=$(info_field "$QUEUE_SOCK" stats instantaneous_ops_per_sec)
    queue_cl=$(info_field "$QUEUE_SOCK" clients connected_clients)
    qlen=$(rcli "$QUEUE_SOCK" LLEN Queue:general 2>/dev/null)
    printf "%-7s %-12s %-12s %-12s %-12s %-12s %-12s\n" \
           "${elapsed}s" "${cache_ops:-?}" "${cache_cl:-?}" "${cache_mem:-?}" \
           "${queue_ops:-?}" "${queue_cl:-?}" "${qlen:-?}"
    sleep "$SAMPLE"
    elapsed=$(( elapsed + SAMPLE ))
done
echo

# End-of-run summaries
print_commandstats "cache" "$CACHE_SOCK"
print_commandstats "queue" "$QUEUE_SOCK"

print_slowlog      "cache" "$CACHE_SOCK"
print_slowlog      "queue" "$QUEUE_SOCK"

print_latency      "cache" "$CACHE_SOCK"
print_latency      "queue" "$QUEUE_SOCK"

# Top clients by command count (helps identify which PF process is the heaviest user)
echo
echo "------ cache CLIENT LIST (sorted by tot-mem) ------"
rcli "$CACHE_SOCK" CLIENT LIST 2>/dev/null \
  | awk '{
        for(i=1;i<=NF;i++){ if($i ~ /^name=/) name=substr($i,6); if($i ~ /^cmd=/) cmd=substr($i,5); if($i ~ /^age=/) age=substr($i,5); if($i ~ /^tot-mem=/) totmem=substr($i,9) }
        printf "%-20s age=%-8s cmd=%-12s tot-mem=%s\n", (name?name:"-"), age, cmd, totmem
    }' \
  | sort -t= -k4 -nr | head -15

echo
echo "------ queue CLIENT LIST (sorted by tot-mem) ------"
rcli "$QUEUE_SOCK" CLIENT LIST 2>/dev/null \
  | awk '{
        for(i=1;i<=NF;i++){ if($i ~ /^name=/) name=substr($i,6); if($i ~ /^cmd=/) cmd=substr($i,5); if($i ~ /^age=/) age=substr($i,5); if($i ~ /^tot-mem=/) totmem=substr($i,9) }
        printf "%-20s age=%-8s cmd=%-12s tot-mem=%s\n", (name?name:"-"), age, cmd, totmem
    }' \
  | sort -t= -k4 -nr | head -15

echo
echo "=== Done ==="
echo "Report: ${OUT}"
echo
echo "If you want a real-time command stream for ~5 seconds (HEAVY — only on a quiet box):"
echo "  timeout 5 redis-cli -s ${CACHE_SOCK} MONITOR | head -200"
