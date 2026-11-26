#!/bin/sh
# Prints the deployed Debian repositories PacketFence X.Y installs from, as "<url> bookworm <component>" lines:
# a feature branch's own branches/X.Y/<pipeline>/ (PF_BRANCHES_PIPELINE) first, then debian/X.Y (its dependencies).
# --check: fail unless the first one is published.
set -eu

# --preferences: the apt pin that keeps a feature branch's packetfence* packages ahead of debian/X.Y's (a newer
# devel build would otherwise win on version); nothing without PF_BRANCHES_PIPELINE.
if [ "${1:-}" = --preferences ]; then
    [ -z "${PF_BRANCHES_PIPELINE:-}" ] || printf 'Package: packetfence*\nPin: release a=bookworm-gitlab\nPin-Priority: 900\n'
    exit 0
fi
check=
if [ "${1:-}" = --check ]; then check=1; shift; fi
release=${1:?usage: deployed-repo.sh [--check] X.Y}
base=${PF_PACKAGE_ORIGIN:-https://packages.packetfence.com}/downloads/PacketFence/debian

if [ -n "${PF_BRANCHES_PIPELINE:-}" ]; then
    first="$base/branches/$release/$PF_BRANCHES_PIPELINE bookworm main"
else
    first="$base/$release bookworm bookworm"
fi
if [ -n "$check" ]; then
    url=${first%% *}
    if ! curl -fsS -o /dev/null "$url/dists/bookworm/InRelease"; then
        hint=
        [ -z "${PF_BRANCHES_PIPELINE:-}" ] || hint=': run this feature branch with DEPLOY_PKG=yes'
        echo "$url is not deployed; images are built from the deployed packages$hint" >&2
        exit 1
    fi
fi
echo "$first"
[ -z "${PF_BRANCHES_PIPELINE:-}" ] || echo "$base/$release bookworm bookworm"
