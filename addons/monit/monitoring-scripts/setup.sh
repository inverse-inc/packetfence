#!/bin/bash

export script_registry_url="http://inverse.ca/downloads/PacketFence/monit-script-registry.txt"
export script_registry_file="/etc/monit.d/checks-script-registry"
export script_dir="/usr/local/pf/var/monitoring-scripts/"

export uuid_file="/etc/monit.d/srv-uuid"

if ! [ -f "$uuid_file" ]; then
  echo "UUID not generated. Proceeding with UUID generation now."
  uuidgen > $uuid_file
fi

export uuid=$(cat $uuid_file)
export uuid_vars_url="http://inverse.ca/downloads/PacketFence/monitoring-scripts/vars/$uuid.txt"
export uuid_vars_file="/etc/monit.d/vars"

export uuid_ignores_url="http://inverse.ca/downloads/PacketFence/monitoring-scripts/ignores/$uuid.txt"
export uuid_ignores_file="/etc/monit.d/ignores"

