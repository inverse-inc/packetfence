#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/functions/helpers.functions

# log the whole upgrade output to a file in addition to STDOUT
setup_upgrade_log

main_splitter
echo "Installing or upgrading the upgrade tools for PacketFence"

apt update
apt install packetfence-upgrade

main_splitter
echo "Starting upgrade process"

/usr/local/pf/addons/full-upgrade/run-upgrade.sh


