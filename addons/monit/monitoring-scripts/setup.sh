#!/bin/bash

if [ -f /etc/redhat-release ] ; then
  monit_dir="/etc/monit.d"
else
  monit_dir="/etc/monit/conf.d"
fi

export script_registry_url="http://inverse.ca/downloads/PacketFence/monitoring-scripts/v1/monit-script-registry.txt"
export script_registry_file="$monit_dir/checks-script-registry"
export script_dir="/usr/local/pf/var/monitoring-scripts/"

export functions_script="$script_dir/.functions.sh"

export uuid_file="$monit_dir/srv-uuid"

if ! [ -f "$uuid_file" ]; then
  echo "UUID not generated. Proceeding with UUID generation now."
  uuidgen > $uuid_file
fi

export uuid=$(cat $uuid_file)
export uuid_vars_url="http://inverse.ca/downloads/PacketFence/monitoring-scripts/v1/vars/$uuid.txt"
export uuid_vars_file="$monit_dir/uuid-vars"

export global_vars_url="http://inverse.ca/downloads/PacketFence/monitoring-scripts/v1/vars.txt"
export global_vars_file="$monit_dir/global-vars"

export local_vars_file="$monit_dir/local-vars"

export uuid_ignores_url="http://inverse.ca/downloads/PacketFence/monitoring-scripts/v1/ignores/$uuid.txt"
export uuid_ignores_file="$monit_dir/uuid-ignores"

export global_ignores_url="http://inverse.ca/downloads/PacketFence/monitoring-scripts/v1/ignores.txt"
export global_ignores_file="$monit_dir/global-ignores"

export local_ignores_file="$monit_dir/local-ignores"

export combined_vars_file="$monit_dir/vars"

function is_ignored {
  touch "$global_ignores_file"
  touch "$uuid_ignores_file"
  touch "$local_ignores_file"
  cmd="$1"
  cat "$global_ignores_file" "$uuid_ignores_file" "$local_ignores_file" | grep "^$cmd$"
  return $?
}

export -f is_ignored

function setup_test_env {
  touch "$global_vars_file"
  touch "$uuid_vars_file"
  touch "$local_vars_file"
  echo "#!/bin/bash" > $combined_vars_file
  cat "$global_vars_file" "$uuid_vars_file" "$local_vars_file" | grep -P '^export [a-zA-Z0-9_]+[=]{1}["]?.*["]?$' >> $combined_vars_file
  chmod +x $combined_vars_file
  source $combined_vars_file
  source $functions_script
}

export -f setup_test_env

