#!/bin/bash

# dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')


die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

get_pf_release() {
    PF_RELEASE_PATH=$(readlink -e ${PF_SRC_DIR}/conf/pf-release)
    PF_MINOR_RELEASE=$(perl -ne 'print $1 if (m/.*?(\d+\.\d+)./)' ${PF_RELEASE_PATH})
}
