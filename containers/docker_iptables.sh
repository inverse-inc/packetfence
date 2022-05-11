#!/bin/bash
set -o nounset -o pipefail
#
function -h {
  cat <<USAGE
  Generate iptables rules for running docker containers. Use
  $(basename $0) -v -n
  to inspect iptables rules without applying changes.
   USAGE: 
   -b / --binary    iptables binary
   -i / --interface Docker virtual interface, default: docker0
   -d / --debug     Debugging output
   -n / --noop      Dry run / no iptables rule is applied
   -v / --verbose   Detailed output
USAGE
}; function --help { -h ;}

function msg { out "$*" >&1 ;}
function out { printf '%s\n' "$*" ;}

function iptables_apply {
  local binary="$1"
  local table="$2"
  local action="$3"
  local rule="$4"
  local noop=$5
  local verbose=$6

  # check if the rule is already defined
  eval "${binary} -t ${table} --check ${rule} 2>/dev/null"
  if [[ $? -ne 0 ]]; then
    if [[ $noop == true ]]; then 
      msg $rule; 
    else 
      if [[ $verbose == true ]]; then
        msg "${rule}"
      fi
      eval "${binary} -t ${table} ${action} ${rule}";
    fi
  fi
}

function main {
  local verbose=false
  local debug=false
  local noop=false
  local interface="docker0"
  local binary="iptables"

  while [[ $# -gt 0 ]]
  do
    case "$1" in                                      # Munging globals, beware
      -i|--interface)       interface="$2"; shift 2 ;;
      -b|--binary)          binary="$2"; shift 2 ;;
      -n|--noop)            noop=true; shift 1 ;;
      -v|--verbose)         verbose=true; shift 1 ;;
      -d|--debug)           debug=true; shift 1 ;;
      *)                    err 'Argument error. Please see help: -h' ;;
    esac
  done

  if [[ $debug == true ]]; then
    set -x
  fi
 
  if [[ $noop == true ]]; then
    msg "NOOP: Only printing iptables rules to be eventually applied"
  fi

  while iptables -L DOCKER ; [ $? -ne 0 ];do
    msg "Waiting for iptables to be ready"
    sleep 5;
  done

  # list currently running container IDs
  local containers=$(docker ps --format '{{.ID}}')
  if [[ ! -z "$containers" ]]; then
    while read -r cont; do
      local ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' ${cont})
      if [[ $verbose == true ]]; then
        msg "Container ${cont}"
      fi    
      # extract port forwarding
      local fwd=$(docker inspect -f '{{json .NetworkSettings.Ports}}' ${cont} | jq -r '. as $a| keys[] | select($a[.]!=null) as $f | "\($f)/\($a[$f][].HostPort)"')
      if [[ ! -z "$fwd" ]]; then      
        while read -r pfwd; do
           local dport protocol hport
           local IFS="/"
           read dport protocol hport <<< "${pfwd}"
           local rule="DOCKER -d ${ip}\/32 ! -i ${interface} -o ${interface} -p ${protocol} -m ${protocol} --dport ${dport} -j ACCEPT"
           iptables_apply "${binary}" "filter" "-A" "${rule}" ${noop} ${verbose}       
           rule="POSTROUTING -s ${ip}\/32 -d ${ip}\/32 -p ${protocol} -m ${protocol} --dport ${dport} -j MASQUERADE"
           iptables_apply "${binary}" "nat" "-A" "${rule}" ${noop} ${verbose}       
           rule="DOCKER ! -i ${interface} -p ${protocol} -m ${protocol} --dport ${hport} -j DNAT --to-destination ${ip}:${dport}"
           iptables_apply "${binary}" "nat" "-A" "${rule}" ${noop} ${verbose}       
        done <<< "$fwd"
      fi
    done <<< "$containers"
  fi
}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then
  case "$1" in
    -h|--help) : ;;
    *) ;;
  esac
  "$@"
else
  main "$@"
fi
