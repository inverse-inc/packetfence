#!/bin/bash
# Register (or deregister) an admin UI plugin, see ../README.md.
#
#   register.sh register <id> <host> <port> [manifest_path] [scheme]
#   register.sh deregister <id>
#
# Run it when the plugin service starts and stops: a Kubernetes postStart and
# preStop hook, a systemd ExecStartPost and ExecStopPost, or the entrypoint of
# the container. Needs redis-cli, uses the same environment as the other
# PacketFence services:
#   REDIS_CACHE_HOST (containers-gateway.internal) REDIS_CACHE_PORT (6379)
#   PFCONFIG_TCP_HOST (containers-gateway.internal) PFCONFIG_TCP_PORT (44444)
set -euo pipefail

REDIS_HOST="${REDIS_CACHE_HOST:-containers-gateway.internal}"
REDIS_PORT="${REDIS_CACHE_PORT:-6379}"
PFCONFIG_HOST="${PFCONFIG_TCP_HOST:-containers-gateway.internal}"
PFCONFIG_PORT="${PFCONFIG_TCP_PORT:-44444}"
KEY='pf:ui_plugins'

# expire the pfconfig namespace built from the registrations
expire() {
  exec 3<>"/dev/tcp/${PFCONFIG_HOST}/${PFCONFIG_PORT}"
  printf '%s\n' '{"method":"expire","namespace":"resource::ui_plugins","light":0,"encoding":"json"}' >&3
  # the answer is a 4 bytes length followed by {"status":"OK."}
  timeout 10 head -c 64 <&3 | grep -q '"OK\."' || { echo "pfconfig did not expire resource::ui_plugins" >&2; exit 1; }
  exec 3<&-
}

case "${1:-}" in
  register)
    id="$2" host="$3" port="$4" path="${5:-/pf-ui/manifest.json}" scheme="${6:-http}"
    printf -v registration '{"id":"%s","scheme":"%s","host":"%s","port":%d,"manifest_path":"%s"}' "$id" "$scheme" "$host" "$port" "$path"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" HSET "$KEY" "$id" "$registration" >/dev/null
    expire
    ;;
  deregister)
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" HDEL "$KEY" "$2" >/dev/null
    expire
    ;;
  *)
    sed -n '2,12p' "$0" >&2
    exit 2
    ;;
esac
