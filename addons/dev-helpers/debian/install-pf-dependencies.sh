#!/bin/bash
set -o nounset -o pipefail -o errexit

export DEBIAN_FRONTEND=noninteractive

# This script will install all PacketFence runtime dependencies

# https://askubuntu.com/a/791865
apt-install-depends() {
    local pkg="$1"
    apt-get install -s "$pkg" | grep -v 'packetfence' \
        | sed -n \
          -e "/^Inst $pkg /d" \
          -e 's/^Inst \([^ ]\+\) .*$/\1/p' \
        | xargs apt-get install -y
}

apt-get -qq update
apt-install-depends packetfence
