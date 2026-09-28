#!/bin/bash
# Consumes conf/install_requested (written by the pfconnector-client when an
# admin asks, from the PacketFence admin interface, for additional PacketFence
# packages on this connector host) and apt-installs them. Only the packages
# listed in ALLOWED can be requested, and apt still verifies every package
# against the PacketFence archive keyring. The PacketFence apt repository is
# the one the connector itself was installed from (same version).
#
# The trigger file is written by the container, which is only semi-trusted:
# runs are rate-limited so a re-dropped trigger cannot keep apt busy, and apt
# runs under the same lock as the upgrade path unit so the two never fight
# over dpkg (an admin may click Upgrade and Install NTLM back to back).
set -o nounset -o pipefail

TRIGGER=/usr/local/pfconnector-remote/conf/install_requested
LOG=/usr/local/pfconnector-remote/conf/install.log
STATE=/usr/local/pfconnector-remote/conf/install_state
STAMP=/run/pfconnector-remote-install.last
LOCK=/run/lock/pfconnector-apt.lock
ALLOWED="packetfence-ntlm-auth-api-remote packetfence-ntlm-auth-join-remote"
MIN_INTERVAL=60

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
state() { printf '%s\n' "$1" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }

[ -f "$TRIGGER" ] || exit 0
requested=$(tr -s '[:space:]' ' ' < "$TRIGGER" | sed 's/^ //; s/ $//')
rm -f "$TRIGGER"

# Rate limit: one attempt per MIN_INTERVAL, whatever the trigger says
if [ -f "$STAMP" ]; then
  last=$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [ $((now - last)) -lt "$MIN_INTERVAL" ]; then
    log "Refusing install of '$requested': last attempt $((now - last))s ago (minimum ${MIN_INTERVAL}s)"
    state "failed: last install attempt $((now - last))s ago, retry in $((MIN_INTERVAL - now + last))s"
    exit 1
  fi
fi
touch "$STAMP"

packages=""
for p in $requested; do
  ok=""
  for a in $ALLOWED; do [ "$p" = "$a" ] && ok=1; done
  if [ -z "$ok" ]; then
    log "Refusing install: package '$p' is not in the allowed list ($ALLOWED)"
    state "failed: package '$p' is not allowed"
    exit 1
  fi
  packages="$packages $p"
done
if [ -z "$packages" ]; then
  log "Refusing install: no package requested"
  state "failed: no package requested"
  exit 1
fi

# One apt user at a time (the upgrade path unit uses the same lock). The
# wait covers a full upgrade run: the install then follows instead of
# failing on dpkg's lock.
mkdir -p "$(dirname "$LOCK")"
exec 9>"$LOCK"
if ! flock -w 600 9; then
  log "Refusing install of$packages: another package operation is still running"
  state "failed:$packages (another package operation is still running, retry later)"
  exit 1
fi

log "Installing$packages"
state "installing:$packages"
export DEBIAN_FRONTEND=noninteractive
if apt-get update >> "$LOG" 2>&1 \
  && apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold $packages >> "$LOG" 2>&1; then
  # The packages' postinst enables their services but does not start them on
  # a fresh install; the admin expects the join service to answer right away
  # (the domain join reaches it through the tunnel). --no-block: the
  # ntlm-auth-api service waits for the tunnel and retries on its own.
  for p in $packages; do
    unit="$p.service"
    if systemctl list-unit-files "$unit" >/dev/null 2>&1 && systemctl is-enabled --quiet "$unit" 2>/dev/null; then
      systemctl start --no-block "$unit" >> "$LOG" 2>&1 && log "Started $unit" || log "Could not start $unit (see journalctl -u $unit)"
    fi
  done
  log "Install of$packages completed"
  state "done:$packages"
else
  log "Install of$packages FAILED, see apt output above"
  state "failed:$packages (see install.log)"
  exit 1
fi
