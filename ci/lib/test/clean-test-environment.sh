#!/bin/bash
set -o nounset -o pipefail -o errexit

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

    if [ "$JOB_STATUS" -eq 0 ]; then
        echo "Passed tests"
        if [ "$KEEP_VMS" = "yes" ]; then
            echo "Keeping VM according to 'KEEP_VMS' value"
            MAKE_TARGET=halt make -e -C ${TEST_DIR} ${CI_JOB_NAME}
        else
            echo "Cleaning VM according to 'KEEP_VMS' value"
            MAKE_TARGET=clean make -e -C ${TEST_DIR} ${CI_JOB_NAME}
        fi
    else
        echo 'Failed tests: cancelling jobs not started and halting VM'
        ${PF_SRC_DIR}/ci/lib/test/cancel-pending-jobs.sh
        MAKE_TARGET=halt make -e -C ${TEST_DIR} ${CI_JOB_NAME}
        exit $JOB_STATUS
    fi

    declare -p JOB_STATUS CI_JOB_NAME
    declare -p TEST_DIR
}


log_section "Configure and check"
configure_and_check
