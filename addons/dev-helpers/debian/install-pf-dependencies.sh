#!/bin/bash
set -o nounset -o pipefail -o errexit

export DEBIAN_FRONTEND=noninteractive

# syntax: pkg1|pkg2|pkg3
PKGS_TO_EXCLUDE=${PKGS_TO_EXCLUDE:-packetfence}

# debian/control of the tree being built (copied there by containers/pfdebian/Dockerfile)
CONTROL_FILE=${CONTROL_FILE:-/tmp/control}

# This script will install all PacketFence runtime dependencies

# https://askubuntu.com/a/791865
apt-install-depends() {
    local pkg="$1"
    apt-get install -s "$pkg" | egrep -v "$PKGS_TO_EXCLUDE" \
        | sed -n \
          -e "/^Inst $pkg /d" \
          -e 's/^Inst \([^ ]\+\) .*$/\1/p' \
        | xargs apt-get -qq --no-install-recommends install -y
}

# The published packetfence package lags behind the tree being built: a
# dependency added on a branch is not in it yet. Install the Pre-Depends and
# Depends of the packetfence stanza of the local control file as well.
apt-install-control-depends() {
    local control="$1"
    local deps
    deps=$(perl -ne '
        next if /^#/;
        if (/^Package:\s*(\S+)/) { $in = $1 eq "packetfence"; next }
        next unless $in;
        if (/^([\w-]+):(.*)/) { $field = $1; $_ = $2 }
        elsif (!/^\s/) { next }
        next unless $field eq "Pre-Depends" || $field eq "Depends";
        print "$_\n" for grep { /\S/ } split /,/;
    ' "$control" \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | grep -v '\${' | egrep -v "$PKGS_TO_EXCLUDE" \
        | paste -sd, -)
    if [ -n "$deps" ]; then
        apt-get -qq --no-install-recommends satisfy -y "$deps"
    fi
}

declare -p PKGS_TO_EXCLUDE
apt-get -qq update
apt-install-depends packetfence
if [ -f "$CONTROL_FILE" ]; then
    apt-install-control-depends "$CONTROL_FILE"
fi
