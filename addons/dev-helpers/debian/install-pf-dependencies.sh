#!/bin/bash
set -o nounset -o pipefail -o errexit

export DEBIAN_FRONTEND=noninteractive

# syntax: pkg1|pkg2|pkg3
PKGS_TO_EXCLUDE=${PKGS_TO_EXCLUDE:-packetfence}

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

declare -p PKGS_TO_EXCLUDE
apt-get -qq update
apt-install-depends packetfence
