#!/bin/bash

# dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

OS_SUPPORTED='RHEL-8 Debian-12'


die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

log_subsection() {
   printf "=\t%s\n" "" "$@" ""
}

get_pf_release() {
    if [ -f "${PF_SRC_DIR}/conf/pf-release" ]; then
        PF_RELEASE_PATH=$(readlink -e ${PF_SRC_DIR}/conf/pf-release)
        PF_MINOR_RELEASE=$(perl -ne 'print $1 if (m/.*?(\d+\.\d+)./)' ${PF_RELEASE_PATH})
        PF_PATCH_RELEASE=$(perl -ne 'print $1 if (m/.*?(\d+\.\d+\.\d+)/)' ${PF_RELEASE_PATH})
    else
        echo "We are not in a PacketFence tree, reading variables from environment"
        PF_MINOR_RELEASE=${PF_MINOR_RELEASE:-99.9}
        PF_PATCH_RELEASE=${PF_PATCH_RELEASE:-99.9.9}
    fi
}

# https://newbedev.com/how-to-urlencode-data-for-curl-command
urlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}
