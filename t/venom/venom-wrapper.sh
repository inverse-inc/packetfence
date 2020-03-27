#!/bin/bash
set -o nounset -o pipefail -o errexit

# Wrapper to run venom tests
die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

# script usage definition
usage() { 
    echo "Usage: $(basename $0) <arg>" 
    echo "   Available targets: setup, pfservers, teardown"
} 


configure_and_check() {
    local dirs=${@:-}
    # colors
    NOCOLOR='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    ORANGE='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    LIGHTGRAY='\033[0;37m'
    DARKGRAY='\033[1;30m'
    LIGHTRED='\033[1;31m'
    LIGHTGREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    LIGHTBLUE='\033[1;34m'
    LIGHTPURPLE='\033[1;35m'
    LIGHTCYAN='\033[1;36m'
    WHITE='\033[1;37m'

    # paths
    VENOM_RESULT_DIR="${VENOM_RESULT_DIR:-${PWD}/results}"
    VENOM_VARS_DIR=${VARS:-${PWD}/vars}
    VENOM_VARS_FILE=${VENOM_VARS_FILE:-${VENOM_VARS_DIR}/all.json}

    mkdir -vp ${VENOM_RESULT_DIR} || die "mkdir failed: ${VENOM_RESULT_DIR}"
    declare -p VENOM_RESULT_DIR VENOM_VARS_FILE
    VENOM="${VENOM:-`which venom`}"
    VENOM_OPTS="${VENOM_OPTS:---format tap --output-dir ${VENOM_RESULT_DIR} --strict --stop-on-failure --var-from-file ${VENOM_VARS_FILE}}"

    echo -e "Using venom using following variables:"
    echo -e "  VENOM=${CYAN}${VENOM}${NOCOLOR}"
    echo -e "  VENOM_OPTS=${CYAN}${VENOM_OPTS}${NOCOLOR}"
    echo ""
}

pfservers_test_suite() {
    local pfservers_dir=${1:-.}
    echo "Running pfservers tests suite"
    for sub_dir in $(find ${pfservers_dir}/* -type d); do
        run_test_suite $sub_dir
    done

}
run_test_suite() {
    local test_suite_dir=$(readlink -e ${1:-.})
    echo "Running ${test_suite_dir}"
    CMD="${VENOM} run ${VENOM_OPTS} ${test_suite_dir}"
    echo -e "  ${YELLOW}${test_suite_dir} ${DARKGRAY}[${CMD}]${NOCOLOR}"
    ${CMD}
}

teardown() {
    rm -rf -v ${VENOM_RESULT_DIR}
}

# Arguments are mandatory
[[ $# -lt 1 ]] && usage && exit 1 
configure_and_check
# test_script_args $@

case $1 in
    setup)
        export VENOM_RESULT_DIR
        run_test_suite setup ;;
    pfservers)
        export VENOM_RESULT_DIR
        source $VENOM_RESULT_DIR/env
        pfservers_test_suite pfservers;;
    teardown) teardown ;;
    *) echo -e "${RED}Error: unknown test suite: $1${NOCOLOR}"
       usage
       exit 1;;
esac
