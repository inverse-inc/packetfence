#!/bin/bash
set -o nounset -o pipefail

# Wrapper to run venom tests
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

# script usage definition
usage() { 
    echo "Usage: $(basename $0) <path_to_test_suite1> [<path_to_test_suite2>]"
    echo "If you want to run all test suites in subdirectories, use <path_to_test_suite_dir/*>"
} 


configure_and_check() {
    # paths
    VENOM_ROOT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))
    VENOM_BINARY="${VENOM_BINARY:-`which venom`}"
    VENOM_COMMON_FLAGS="${VENOM_COMMON_FLAGS:-}"
    VENOM_EXIT_FLAGS="${VENOM_EXIT_FLAGS:-}"

    echo -e "Using venom using following variables:"
    echo -e "  VENOM_BINARY=${VENOM_BINARY}"
    echo -e "  VENOM_ALL_FLAGS=${VENOM_COMMON_FLAGS} ${VENOM_EXIT_FLAGS}"
    echo ""
}

die_on_error() {
    die "Error in Venom tests"
}

run_test_suites() {
    local test_suites=$(readlink -e ${@:-.})
    log_section "Running ${test_suites} test suite(s)"
    CMD="${VENOM_BINARY} run ${VENOM_COMMON_FLAGS} ${VENOM_EXIT_FLAGS} ${test_suites}"
    ${CMD} || die_on_error
}

# Arguments are mandatory
[[ $# -lt 1 ]] && usage && exit 1
configure_and_check

run_test_suites $@

