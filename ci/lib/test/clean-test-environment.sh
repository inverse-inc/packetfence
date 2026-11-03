#!/bin/bash
# no '-o errexit': errors are managed in script
set -o nounset -o pipefail

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# full path to test dir
TEST_DIR=${PF_SRC_DIR}/t/venom

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}


configure_and_check() {
    JOB_STATUS=${JOB_STATUS:-0}
    CI_JOB_NAME=${CI_JOB_NAME:-}
    KEEP_VMS=${KEEP_VMS:-no}
    TEST_ONLY=${TEST_ONLY:-}
    CI_PIPELINE_SOURCE=${CI_PIPELINE_SOURCE:-}

    declare -p JOB_STATUS CI_JOB_NAME
    declare -p TEST_DIR

    # Retention is for explicitly selected debug tests, not full pipelines.
    # Reuse the job selector so empty, invalid, or nonmatching filters cannot
    # keep VMs when this script is invoked outside the usual CI entry point.
    if [ "$KEEP_VMS" = "yes" ]; then
        if [ -z "$TEST_ONLY" ] || ! TEST_ONLY="$TEST_ONLY" CI_JOB_NAME="$CI_JOB_NAME" \
            bash "${PF_SRC_DIR}/ci/lib/test/test-only-matches.sh"; then
            echo "WARN: KEEP_VMS=yes requires TEST_ONLY to select this job; VMs will be cleaned"
            KEEP_VMS=no
        fi
    fi

    # Successful tests leave JOB_STATUS unset (or explicitly zero).
    if [ "$JOB_STATUS" = "0" ]; then
        echo "Passed tests"
    else
        echo "\nFailed tests\n"
        # We don't want other jobs to be canceled when running a manual pipeline
        if [ "$CI_PIPELINE_SOURCE" = "schedule" ]; then
            echo "\nCancelling jobs not started and then teardown VM\n"
            ${PF_SRC_DIR}/ci/lib/test/cancel-pending-jobs.sh
        fi
    fi

    # Keep debugging VMs regardless of the test result; still collect logs.
    if [ "$KEEP_VMS" = "yes" ]; then
        echo "\nKeeping VM according to 'KEEP_VMS' value\n"
        teardown
    else
        echo "\nCleaning VM according to 'KEEP_VMS' value\n"
        teardown_clean
    fi
    local cleanup_status=$?
    # Preserve the original test failure. For successful tests, report any
    # cleanup failure instead.
    if [ "$JOB_STATUS" != "0" ]; then
        exit "$JOB_STATUS"
    fi
    exit "$cleanup_status"
}

# best-effort and bounded so a hung log fetch can't starve the destroy below
teardown() {
    timeout "${PIPELINE_TIMEOUT_TEARDOWN:-6m}" \
        env MAKE_TARGET=teardown make -e -C ${TEST_DIR} ${CI_JOB_NAME} \
        || echo "WARN: log collection timed out or failed, continuing"
}

# VM destroy, bounded and independent from log collection; its exit code decides cleanup success
clean() {
    timeout "${PIPELINE_TIMEOUT_CLEAN:-3m}" \
        env MAKE_TARGET=clean make -e -C ${TEST_DIR} ${CI_JOB_NAME}
}

teardown_clean() {
    teardown
    clean
}

log_section "Configure and check"
configure_and_check
