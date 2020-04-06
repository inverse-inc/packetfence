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
    echo "Usage: $(basename $0) <path_to_test_suite> or <path_to_test_suite_dir>"
    echo "$(basename $0) <pfservers> is specific and will run all test suite in all subdirectories"
} 


configure_and_check() {
    # paths
    VENOM_RESULT_DIR="${VENOM_RESULT_DIR:-${PWD}/results}"
    VENOM_VARS_DIR=${VARS:-${PWD}/vars}
    VENOM_VARS_FILE=${VENOM_VARS_FILE:-${VENOM_VARS_DIR}/all.yml}

    mkdir -vp ${VENOM_RESULT_DIR} || die "mkdir failed: ${VENOM_RESULT_DIR}"
    declare -p VENOM_RESULT_DIR VENOM_VARS_FILE
    VENOM_BINARY="${VENOM_BINARY:-`which venom`}"
    VENOM_FORMAT=${VENOM_FORMAT:-tap}
    VENOM_COMMON_FLAGS="${VENOM_COMMON_FLAGS:---format ${VENOM_FORMAT} --output-dir ${VENOM_RESULT_DIR} --var-from-file ${VENOM_VARS_FILE}}"
    VENOM_EXIT_FLAGS="${VENOM_EXIT_FLAGS:---strict --stop-on-failure}"

    echo -e "Using venom using following variables:"
    echo -e "  VENOM_BINARY=${VENOM_BINARY}"
    echo -e "  VENOM_FLAGS=${VENOM_COMMON_FLAGS} ${VENOM_EXIT_FLAGS}"
    echo ""
}

pfservers_test_suite() {
    local pfservers_dir=${1:-.}
    for sub_dir in $(find ${pfservers_dir}/* -type d); do
        run_test_suite $sub_dir
    done

}
run_test_suite() {
    local test_suite_dir=$(readlink -e ${1:-.})
    local test_suite_name=$(basename $test_suite_dir)
    log_section "Running ${test_suite_dir} suite"
    CMD="${VENOM_BINARY} run ${VENOM_COMMON_FLAGS} ${VENOM_EXIT_FLAGS} ${test_suite_dir}"
    ${CMD} > ${VENOM_RESULT_DIR}/${test_suite_name}.output 2>&1

    # display error logs only on error (need --strict)
    if [ "$?" -ne 0 ]; then
        cat ${VENOM_RESULT_DIR}/${test_suite_name}.output
    else
        cat ${VENOM_RESULT_DIR}/test_results.${VENOM_FORMAT}
    fi
}

teardown() {
    rm -rf ${VENOM_RESULT_DIR} || die "rm failed: ${VENOM_RESULT_DIR}"
}

# Arguments are mandatory
[[ $# -lt 1 ]] && usage && exit 1
configure_and_check

case $1 in
    # run all test suite file in each subdirectories of pfservers dir
    # source "env" file to have API token if exist
    pfservers)
        export VENOM_RESULT_DIR
        if [ -f "${VENOM_RESULT_DIR}/env" ]; then
            source $VENOM_RESULT_DIR/env
        fi
        pfservers_test_suite pfservers;;
    teardown) teardown ;;
    # run all test suite files in a arg directory
    # source "env" file to have API token if exist
    *)
        export VENOM_RESULT_DIR
        if [ -f "${VENOM_RESULT_DIR}/env" ]; then
            source $VENOM_RESULT_DIR/env
        fi
        run_test_suite $1 ;;
esac
