#!/bin/bash
# Consumes conf/upgrade_requested (written by the pfconnector-client when an
# admin triggers an upgrade from the PacketFence admin interface), points the
# PacketFence apt repository at the requested version and upgrades the
# packetfence-pfconnector-remote package. apt still verifies every package
# against the PacketFence archive keyring, so only signed PacketFence
# packages can ever be installed through this path.
set -o nounset -o pipefail

TRIGGER=/usr/local/pfconnector-remote/conf/upgrade_requested
LOG=/usr/local/pfconnector-remote/conf/upgrade.log
PACKAGE=packetfence-pfconnector-remote

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

[ -f "$TRIGGER" ] || exit 0
target=$(head -1 "$TRIGGER" | tr -d '[:space:]')
rm -f "$TRIGGER"

# Strict validation: the value ends up in the apt sources configuration
if ! echo "$target" | grep -qE '^[0-9]+\.[0-9]+$'; then
  log "Refusing upgrade: invalid target version '$target'"
  exit 1
fi

current=$(dpkg-query -W -f '${Version}' "$PACKAGE" 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+')
if [ -n "$current" ] && dpkg --compare-versions "$target" lt "$current"; then
  log "Refusing downgrade from $current to $target"
  exit 1
fi

log "Upgrading $PACKAGE to PacketFence $target (currently ${current:-unknown})"

# Point the PacketFence repository at the target version wherever it is
# configured (the sources file name varies between installs)
changed=""
for list in /etc/apt/sources.list.d/*.list; do
  [ -f "$list" ] || continue
  if grep -qE 'inverse\.ca/downloads/PacketFence/debian/[0-9]+\.[0-9]+' "$list"; then
    sed -i -E "s|(inverse\.ca/downloads/PacketFence/debian/)[0-9]+\.[0-9]+|\1${target}|g" "$list"
    changed="$changed $list"
  fi
done
if [ -z "$changed" ]; then
  log "No PacketFence repository entry found in /etc/apt/sources.list.d, aborting"
  exit 1
fi
log "Repository version set to $target in:$changed"

export DEBIAN_FRONTEND=noninteractive
if apt-get update >> "$LOG" 2>&1 \
  && apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$PACKAGE" >> "$LOG" 2>&1; then
  log "Upgrade to $target completed"
else
  log "Upgrade to $target FAILED, see apt output above"
  exit 1
fi
