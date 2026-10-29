#!/bin/bash
# Consumes conf/services_requested (written by the pfconnector-client when an
# admin acts on the NTLM authentication services of this host from the
# PacketFence admin interface): starts, stops or restarts the requested
# systemd unit, then writes the state of every managed unit to
# conf/services_state for the connector to report. A "status" request only
# refreshes that state.
#
# The units run on the host (docker containers started by systemd), out of
# reach of the connector container, which has no access to the host's
# systemd: the request goes through this trigger file, watched by
# packetfence-pfconnector-services.path. The trigger file is written by the
# container, which is only semi-trusted: only the units listed below can be
# acted on, runs are paced, and nothing from the trigger is executed or copied
# to the log.
set -o nounset -o pipefail

CONF=/usr/local/pfconnector-remote/conf
TRIGGER=$CONF/services_requested
STATE=$CONF/services_state
LAST=$CONF/services_last_action
LOG=$CONF/services.log
STAMP=/run/pfconnector-remote-services.last
MIN_INTERVAL=2
# Units the admin may act on: the NTLM authentication services, plus the
# per-domain instances of the NTLM API, whose instance name is the domain's
# identifier in PacketFence (one unit per domain behind the connector).
FIXED_UNITS="packetfence-ntlm-auth-api-remote.service packetfence-ntlm-auth-join-remote.service"
DOMAIN_TEMPLATE="packetfence-ntlm-auth-api-domain-remote"
DOMAIN_UNIT_RE="^${DOMAIN_TEMPLATE}@[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.service$"

# conf/ is writable by the connector container while this script runs as
# root on the host: never follow a symlink placed there.

# The log is opened once, and the opened file checked afterwards: a symlink
# swapped in between can't redirect the output.
if [ -L "$LOG" ] || { [ -e "$LOG" ] && [ ! -f "$LOG" ]; }; then
  echo "Refusing service request: $LOG is not a regular file" >&2
  exit 1
fi
exec 3>>"$LOG"
if [ "$(readlink -f /proc/$$/fd/3)" != "$(readlink -f "$(dirname "$LOG")")/$(basename "$LOG")" ]; then
  echo "Refusing service request: $LOG changed while it was opened" >&2
  exit 1
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&3; }
now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# Files in conf/ are replaced by a rename of a fresh file (mktemp creates it
# exclusively, rename replaces a symlink instead of following it).
publish() {
  local target=$1 tmp
  tmp=$(mktemp "$(dirname "$target")/.$(basename "$target").XXXXXX") || return 1
  chmod 0644 "$tmp" && cat > "$tmp" && mv -f "$tmp" "$target" || { rm -f "$tmp"; return 1; }
}

# JSON string escaping for the few free-text values (unit descriptions,
# systemctl messages).
json_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/ }
  s=${s//$'\t'/ }
  printf '"%s"' "$s"
}

unit_allowed() {
  local u=$1 a
  for a in $FIXED_UNITS; do [ "$u" = "$a" ] && return 0; done
  [[ "$u" =~ $DOMAIN_UNIT_RE ]]
}

# The managed units: the fixed ones, and every instance of the domain
# template: the ones systemd knows (loaded, or enabled with a unit file) and
# the ones of the domains configured on this host, which the NTLM API
# controller starts from the <domain>.env files pfconnector-remote-load.sh
# generates (a stopped instance is forgotten by systemd, not by us).
DOMAIN_ENV_DIR=/usr/local/ntlm-auth-api/var/conf
managed_units() {
  local u f
  for u in $FIXED_UNITS; do echo "$u"; done
  {
    systemctl list-units --all --plain --no-legend "${DOMAIN_TEMPLATE}@*.service" 2>/dev/null | awk '{print $1}'
    systemctl list-unit-files --plain --no-legend "${DOMAIN_TEMPLATE}@*.service" 2>/dev/null | awk '{print $1}'
    for f in "$DOMAIN_ENV_DIR"/*.env; do
      [ -f "$f" ] || continue
      u=$(basename "$f" .env)
      echo "${DOMAIN_TEMPLATE}@${u}.service"
    done
  } | grep -E "$DOMAIN_UNIT_RE" | sort -u
}

# One JSON object per unit, from systemctl show.
unit_json() {
  local u=$1 installed=true
  local ActiveState= SubState= UnitFileState= NRestarts= ExecMainStartTimestamp= Description=
  if ! systemctl cat "$u" >/dev/null 2>&1; then
    installed=false
  fi
  while IFS='=' read -r key value; do
    case "$key" in
      ActiveState|SubState|UnitFileState|NRestarts|ExecMainStartTimestamp|Description) printf -v "$key" '%s' "$value" ;;
    esac
  done < <(systemctl show -p ActiveState,SubState,UnitFileState,NRestarts,ExecMainStartTimestamp,Description "$u" 2>/dev/null)
  [[ "$NRestarts" =~ ^[0-9]+$ ]] || NRestarts=0
  printf '{"name":%s,"installed":%s,"active_state":%s,"sub_state":%s,"unit_file_state":%s,"restarts":%s,"since":%s,"description":%s}' \
    "$(json_str "$u")" "$installed" "$(json_str "${ActiveState:-unknown}")" "$(json_str "${SubState:-}")" \
    "$(json_str "${UnitFileState:-}")" "$NRestarts" "$(json_str "${ExecMainStartTimestamp:-}")" "$(json_str "${Description:-}")"
}

write_state() {
  local first=1 u last=null
  if [ -f "$LAST" ] && [ ! -L "$LAST" ]; then
    last=$(head -c 2048 "$LAST")
    [ -n "$last" ] || last=null
  fi
  {
    printf '{"updated":%s,"last_action":%s,"services":[' "$(json_str "$(now_iso)")" "$last"
    while read -r u; do
      [ -n "$u" ] || continue
      [ $first = 1 ] || printf ','
      first=0
      unit_json "$u"
    done < <(managed_units)
    printf ']}\n'
  } | publish "$STATE"
}

record_action() {
  local action=$1 unit=$2 result=$3 message=$4
  printf '{"action":%s,"unit":%s,"at":%s,"result":%s,"message":%s}' \
    "$(json_str "$action")" "$(json_str "$unit")" "$(json_str "$(now_iso)")" "$(json_str "$result")" "$(json_str "$message")" | publish "$LAST"
}

[ -e "$TRIGGER" ] || [ -L "$TRIGGER" ] || exit 0
if [ -L "$TRIGGER" ] || [ ! -f "$TRIGGER" ]; then
  rm -f "$TRIGGER"
  log "Refusing service request: the request is not a regular file"
  exit 1
fi
read -r action unit _ < <(head -c 256 "$TRIGGER" | tr -s '[:space:]' ' '; echo)
rm -f "$TRIGGER"
action=${action:-}
unit=${unit:-}

# Pacing: at most one run per MIN_INTERVAL, whatever the trigger says. A
# request that comes too early waits for its turn instead of being dropped
# (the path unit runs one request at a time): an action clicked right after
# a status refresh must not be lost.
if [ -f "$STAMP" ]; then
  last_run=$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)
  wait=$((MIN_INTERVAL - ($(date +%s) - last_run)))
  if [ "$wait" -gt 0 ] && [ "$wait" -le "$MIN_INTERVAL" ]; then
    sleep "$wait"
  fi
fi
touch "$STAMP"

case "$action" in
  status)
    write_state
    exit 0
    ;;
  start|stop|restart)
    ;;
  *)
    log "Refusing service request: unknown action"
    record_action "" "" "failed" "unknown action requested"
    write_state
    exit 1
    ;;
esac

if ! unit_allowed "$unit"; then
  log "Refusing to $action a unit that is not an NTLM authentication service"
  record_action "$action" "" "failed" "the requested unit is not an NTLM authentication service"
  write_state
  exit 1
fi

log "$action $unit (requested from the admin interface)"
if message=$(systemctl "$action" "$unit" 2>&1); then
  log "$action $unit: done"
  record_action "$action" "$unit" "ok" ""
else
  log "$action $unit: failed: $message"
  record_action "$action" "$unit" "failed" "$message"
fi
# The unit's state right after systemctl returns: a Type=notify unit is
# already active or failed, a forking one may still be activating; the next
# status refresh catches up.
write_state
exit 0
