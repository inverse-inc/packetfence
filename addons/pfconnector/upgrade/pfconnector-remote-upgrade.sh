#!/bin/bash
# Consumes conf/upgrade_requested (written by the pfconnector-client when an
# admin triggers an upgrade from the PacketFence admin interface), points the
# PacketFence apt repository at the requested version and upgrades the
# packetfence-pfconnector-remote package. apt still verifies every package
# against the PacketFence archive keyring, so only signed PacketFence
# packages can ever be installed through this path.
#
# The trigger file is written by the container, which is only semi-trusted:
# the target is strictly validated, downgrades are refused, the repository
# change is verified with `apt-get update` before it is kept (and reverted
# otherwise, so a bad target cannot leave the host with a dead repository),
# and runs are rate-limited so a re-dropped trigger cannot keep apt busy.
set -o nounset -o pipefail

TRIGGER=/usr/local/pfconnector-remote/conf/upgrade_requested
LOG=/usr/local/pfconnector-remote/conf/upgrade.log
STAMP=/run/pfconnector-remote-upgrade.last
LOCK=/run/lock/pfconnector-apt.lock
PACKAGE=packetfence-pfconnector-remote
MIN_INTERVAL=300

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

[ -f "$TRIGGER" ] || exit 0
target=$(head -1 "$TRIGGER" | tr -d '[:space:]')
rm -f "$TRIGGER"

# Strict validation: the value ends up in the apt sources configuration
if ! echo "$target" | grep -qE '^[0-9]+\.[0-9]+$'; then
  log "Refusing upgrade: invalid target version '$target'"
  exit 1
fi

# Rate limit: one attempt per MIN_INTERVAL, whatever the trigger says
if [ -f "$STAMP" ]; then
  last=$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [ $((now - last)) -lt "$MIN_INTERVAL" ]; then
    log "Refusing upgrade to $target: last attempt $((now - last))s ago (minimum ${MIN_INTERVAL}s)"
    exit 1
  fi
fi
touch "$STAMP"

# One apt user at a time (the NTLM services install path unit uses the same lock)
mkdir -p "$(dirname "$LOCK")"
exec 9>"$LOCK"
if ! flock -w 600 9; then
  log "Refusing upgrade to $target: another package operation is still running"
  exit 1
fi

current=$(dpkg-query -W -f '${Version}' "$PACKAGE" 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+')
if [ -n "$current" ] && dpkg --compare-versions "$target" lt "$current"; then
  log "Refusing downgrade from $current to $target"
  exit 1
fi

log "Upgrading $PACKAGE to PacketFence $target (currently ${current:-unknown})"

# Point the PacketFence repository at the target version wherever it is
# configured, keeping a copy of every file touched to revert on failure
repo_re='inverse\.ca/downloads/PacketFence/debian/[0-9]+\.[0-9]+'
backup=$(mktemp -d /run/pfconnector-remote-upgrade.XXXXXX)
changed=()
for list in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
  [ -f "$list" ] || continue
  grep -qE "$repo_re" "$list" || continue
  cp -a "$list" "$backup/$(echo "$list" | tr / _)"
  sed -i -E "s|(inverse\.ca/downloads/PacketFence/debian/)[0-9]+\.[0-9]+|\1${target}|g" "$list"
  changed+=("$list")
done
if [ "${#changed[@]}" -eq 0 ]; then
  log "No PacketFence repository entry found in the apt sources, aborting"
  rmdir "$backup"
  exit 1
fi
log "Repository version set to $target in: ${changed[*]}"

revert() {
  for list in "${changed[@]}"; do
    cp -a "$backup/$(echo "$list" | tr / _)" "$list"
  done
  rm -rf "$backup"
  log "Repository configuration restored"
  apt-get update >> "$LOG" 2>&1 || true
}

export DEBIAN_FRONTEND=noninteractive
# The target must exist: a well-formed but unknown version would otherwise
# leave every later apt operation on this host broken
if ! apt-get update >> "$LOG" 2>&1; then
  log "Upgrade to $target FAILED: the repository for that version is not available"
  revert
  exit 1
fi
if ! apt-cache policy "$PACKAGE" 2>/dev/null | grep -qE "downloads/PacketFence/debian/${target//./\\.}[ /]"; then
  log "Upgrade to $target FAILED: $PACKAGE is not offered by the $target repository"
  revert
  exit 1
fi
if apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$PACKAGE" >> "$LOG" 2>&1; then
  log "Upgrade to $target completed"
  rm -rf "$backup"
else
  log "Upgrade to $target FAILED, see apt output above"
  revert
  exit 1
fi
