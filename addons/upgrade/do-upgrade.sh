#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/functions/helpers.functions

main_splitter
echo "Installing or upgrading the upgrade tools for PacketFence"

if is_rpm_based; then
  if rpm -q packetfence-upgrade; then
    yum update packetfence-upgrade --enablerepo=packetfence
  else
    yum install packetfence-upgrade --enablerepo=packetfence
  fi
else
  apt install packetfence-upgrade
fi

main_splitter
echo "Starting upgrade process"

/usr/local/pf/addons/full-upgrade/run-upgrade.sh


