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
    echo "A test suite can be a directory or a YAML file"
    echo "When a directory is passed, this script will sort alphabetically all test suites files in it"
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
    log_section "Running Venom test suite ${test_suites}"

    # empty array
    test_suites_files=()
    for test_suite in ${test_suites}; do
        # if it's a directory, we sort alphabetically files in it
        if [ -d "${test_suite}" ]; then
            sorted_files=$(find ${test_suite} -maxdepth 1 -type f,l -name "*.yml" | sort)
            test_suites_files+=($sorted_files)
        else
            test_suites_files+=($test_suite)
        fi
    done

    CMD="${VENOM_BINARY} run ${VENOM_COMMON_FLAGS} ${VENOM_EXIT_FLAGS} ${test_suites_files[@]}"
    ${CMD} || die_on_error
}

# Arguments are mandatory
[[ $# -lt 1 ]] && usage && exit 1
configure_and_check
run_test_suites $@

