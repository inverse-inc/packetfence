#!/usr/bin/env bash
# Run on the PacketFence server while k6 is hammering the portal.
# Samples the things most likely to be the first wall: haproxy + httpd.portal
# container CPU, MariaDB threads, pfqueue depth, and Redis memory.
#
# Usage:  ./probe.sh [interval_seconds] [iterations]
# Default: 5s interval, runs until Ctrl-C.

set -u
INTERVAL="${1:-5}"
ITERS="${2:-0}"  # 0 = forever

echo "ts                  haproxy_cpu  portal_cpu   mariadb_run  pfq_general  pfq_pfdhcp   redis_mem"

i=0
while :; do
  ts=$(date +%Y-%m-%dT%H:%M:%S)

  haproxy_cpu=$(docker stats --no-stream --format '{{.CPUPerc}}' haproxy-portal 2>/dev/null | tr -d '%' || echo "?")
  portal_cpu=$( docker stats --no-stream --format '{{.CPUPerc}}' httpd.portal   2>/dev/null | tr -d '%' || echo "?")

  mariadb_run=$(mysql -BN -e "SHOW STATUS LIKE 'Threads_running'" 2>/dev/null | awk '{print $2}')
  : "${mariadb_run:=?}"

  # pfqueue depth — adjust path to redis-cli for your container if needed
  pfq_general=$(redis-cli -p 6379 -n 0 LLEN 'pfqueue-general' 2>/dev/null || echo "?")
  pfq_pfdhcp=$( redis-cli -p 6379 -n 0 LLEN 'pfqueue-pfdhcplistener' 2>/dev/null || echo "?")

  redis_mem=$(redis-cli -p 6379 INFO memory 2>/dev/null | awk -F: '/^used_memory_human:/ {gsub(/\r/,""); print $2}')
  : "${redis_mem:=?}"

  printf "%s  %-11s  %-11s  %-11s  %-11s  %-11s  %s\n" \
    "$ts" "$haproxy_cpu" "$portal_cpu" "$mariadb_run" "$pfq_general" "$pfq_pfdhcp" "$redis_mem"

  i=$((i+1))
  [ "$ITERS" -gt 0 ] && [ "$i" -ge "$ITERS" ] && break
  sleep "$INTERVAL"
done
