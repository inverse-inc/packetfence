#!/bin/bash

set -o nounset -o pipefail -o errexit

# log the whole upgrade output to a file in addition to STDOUT
if [ -z "${PF_UPGRADE_LOG:-}" ]; then
  export PF_UPGRADE_LOG="/usr/local/pf/logs/pf-upgrade-$(date +%Y%m%d_%H%M%S).log"
  mkdir -p "$(dirname "$PF_UPGRADE_LOG")"
  exec > >(tee -a "$PF_UPGRADE_LOG") 2>&1
  echo "The output of this upgrade is logged to $PF_UPGRADE_LOG"
fi

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
  apt update
  apt install packetfence-upgrade
fi

main_splitter
echo "Starting upgrade process"

/usr/local/pf/addons/full-upgrade/run-upgrade.sh


