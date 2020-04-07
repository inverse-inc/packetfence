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

# will display:
# errors if found (when Venom use --strict mode, default here)
# or
# test results
check_failure() {
    local venom_exit_status=${1}

    if [ "$venom_exit_status" -ne 0 ]; then
        cat ${VENOM_RESULT_DIR}/${test_suite_name}.output
        exit $venom_exit_status
    else
        # test results file, will be replace at next Venom run
        cat ${VENOM_RESULT_DIR}/test_results.${VENOM_FORMAT}
    fi
}

teardown() {
    rm -rf ${VENOM_RESULT_DIR} || die "rm failed: ${VENOM_RESULT_DIR}"
}


# run all test suite files in each subdirectories of top_dir
run_nested_test_suites() {
    local top_dir=${1:-.}
    for sub_dir in $(find ${top_dir}/* -type d); do
        run_test_suite $sub_dir
    done

}

# run all test suite files in a arg directory or a test suite file (Venom current behavior)
run_test_suite() {
    local test_suite=$(readlink -e ${1:-.})
    local test_suite_name=$(basename $test_suite)
    log_section "Running ${test_suite} suite"
    CMD="${VENOM_BINARY} run ${VENOM_COMMON_FLAGS} ${VENOM_EXIT_FLAGS} ${test_suite}"
    ${CMD} > ${VENOM_RESULT_DIR}/${test_suite_name}.output 2>&1
    check_failure $?
}

# Arguments are mandatory
[[ $# -lt 1 ]] && usage && exit 1
configure_and_check

for target in $@; do
    case $target in
        # source "env" file to have API token if exist
        pfservers)
            export VENOM_RESULT_DIR
            if [ -f "${VENOM_RESULT_DIR}/env" ]; then
                source $VENOM_RESULT_DIR/env
            fi
            run_nested_test_suites $target ;;
        teardown) teardown ;;
        # source "env" file to have API token if exist
        *)
            export VENOM_RESULT_DIR
            if [ -f "${VENOM_RESULT_DIR}/env" ]; then
                source $VENOM_RESULT_DIR/env
            fi
            run_test_suite $target ;;
    esac
done
