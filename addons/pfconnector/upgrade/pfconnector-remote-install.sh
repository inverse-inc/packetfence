#!/bin/bash
# Consumes conf/install_requested (written by the pfconnector-client when an
# admin asks, from the PacketFence admin interface, for additional PacketFence
# packages on this connector host) and apt-installs them. Only the packages
# listed in ALLOWED can be requested, and apt still verifies every package
# against the PacketFence archive keyring. The PacketFence apt repository is
# the one the connector itself was installed from (same version).
set -o nounset -o pipefail

TRIGGER=/usr/local/pfconnector-remote/conf/install_requested
LOG=/usr/local/pfconnector-remote/conf/install.log
STATE=/usr/local/pfconnector-remote/conf/install_state
ALLOWED="packetfence-ntlm-auth-api-remote packetfence-ntlm-auth-join-remote"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
state() { printf '%s\n' "$1" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }

[ -f "$TRIGGER" ] || exit 0
requested=$(tr -s '[:space:]' ' ' < "$TRIGGER" | sed 's/^ //; s/ $//')
rm -f "$TRIGGER"

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
