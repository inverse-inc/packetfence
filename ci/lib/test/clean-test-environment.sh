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
    JOB_STATUS=${JOB_STATUS:-}
    CI_JOB_NAME=${CI_JOB_NAME:-}
    KEEP_VMS=${KEEP_VMS:-no}
    CI_PIPELINE_SOURCE=${CI_PIPELINE_SOURCE:-}

    declare -p JOB_STATUS CI_JOB_NAME
    declare -p TEST_DIR

    # if test was a success, JOB_STATUS is unset
    # so we test is has zero length
    if [ -z "$JOB_STATUS" ]; then
        echo "Passed tests"
        if [ "$KEEP_VMS" = "yes" ]; then
            echo "\nKeeping VM according to 'KEEP_VMS' value\n"
            teardown
        else
            echo "\nCleaning VM according to 'KEEP_VMS' value\n"
            teardown_clean
        fi
	# even if tests passed, we want to exit with return code of last command
	# to detect a potential failure during cleanup
	# if there is no failure, job must be marked as passed
	exit $?
    else
        echo "\nFailed tests\n"
        # We don't want other jobs to be canceled when running a manual pipeline
        if [ "$CI_PIPELINE_SOURCE" = "schedule" ]; then
            echo "\nCancelling jobs not started and then teardown VM\n"
            ${PF_SRC_DIR}/ci/lib/test/cancel-pending-jobs.sh
        fi
        echo "\nTeardown VMs\n"
        teardown_clean
        exit $JOB_STATUS
    fi
}

# best-effort and bounded so a hung log fetch can't starve the destroy below
teardown() {
    timeout "${PIPELINE_TIMEOUT_TEARDOWN:-6m}" \
        env MAKE_TARGET=teardown make -e -C ${TEST_DIR} ${CI_JOB_NAME} \
        || echo "WARN: log collection timed out or failed, continuing to VM destroy"
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
