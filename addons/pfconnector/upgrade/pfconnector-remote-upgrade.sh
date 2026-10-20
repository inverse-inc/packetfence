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

# conf/ is writable by the connector container while this script runs as
# root on the host: never follow a symlink placed there, and never copy
# what the trigger contains to the log.

# The log is opened once, and the opened file checked afterwards: a symlink
# swapped in between can't redirect the output.
if [ -L "$LOG" ] || { [ -e "$LOG" ] && [ ! -f "$LOG" ]; }; then
  echo "Refusing upgrade: $LOG is not a regular file" >&2
  exit 1
fi
exec 3>>"$LOG"
if [ "$(readlink -f /proc/$$/fd/3)" != "$(readlink -f "$(dirname "$LOG")")/$(basename "$LOG")" ]; then
  echo "Refusing upgrade: $LOG changed while it was opened" >&2
  exit 1
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&3; }

[ -e "$TRIGGER" ] || [ -L "$TRIGGER" ] || exit 0
if [ -L "$TRIGGER" ] || [ ! -f "$TRIGGER" ]; then
  rm -f "$TRIGGER"
  log "Refusing upgrade: the upgrade request is not a regular file"
  exit 1
fi
target=$(head -c 64 "$TRIGGER" | head -1 | tr -d '[:space:]')
rm -f "$TRIGGER"

# Strict validation: the value ends up in the apt sources configuration
if ! echo "$target" | grep -qE '^[0-9]+\.[0-9]+$'; then
  log "Refusing upgrade: invalid target version"
  exit 1
fi

current=$(dpkg-query -W -f '${Version}' "$PACKAGE" 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+')
if [ -n "$current" ] && dpkg --compare-versions "$target" lt "$current"; then
  log "Refusing downgrade from $current to $target"
  exit 1
fi

log "Upgrading $PACKAGE to PacketFence $target (currently ${current:-unknown})"

# Point the PacketFence repository at the target version wherever it is
# configured: the sources file name varies between installs, and it can be in
# the one-line format (sources.list, *.list) or the deb822 format (*.sources,
# the default since Debian 13), where the URL is on the URIs: line
# The sources files are restored if the upgrade fails (no repository for
# that version and Debian release, ...), so apt keeps working on the host.
backup=$(mktemp -d /var/tmp/pfconnector-upgrade-sources.XXXXXX)
restore_sources() {
  for list in $changed; do
    cp -p "$backup/$(echo "$list" | tr / _)" "$list"
  done
  log "Repository configuration restored"
}

changed=""
for list in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
  [ -f "$list" ] || continue
  if grep -qE 'inverse\.ca/downloads/PacketFence/debian/[0-9]+\.[0-9]+' "$list"; then
    cp -p "$list" "$backup/$(echo "$list" | tr / _)"
    sed -i -E "s|(inverse\.ca/downloads/PacketFence/debian/)[0-9]+\.[0-9]+|\1${target}|g" "$list"
    changed="$changed $list"
  fi
done
if [ -z "$changed" ]; then
  rm -rf "$backup"
  log "No PacketFence repository entry found in /etc/apt/sources.list or /etc/apt/sources.list.d, aborting"
  exit 1
fi
log "Repository version set to $target in:$changed"

export DEBIAN_FRONTEND=noninteractive
if apt-get update >&3 2>&1 \
  && apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$PACKAGE" >&3 2>&1; then
  rm -rf "$backup"
  log "Upgrade to $target completed"
else
  log "Upgrade to $target FAILED, see apt output above"
  restore_sources
  apt-get update >&3 2>&1 || true
  rm -rf "$backup"
  exit 1
fi
