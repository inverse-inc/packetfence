#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}


configure_and_check() {
    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}
    CI_COMMIT_REF_SLUG=${CI_COMMIT_REF_SLUG:-}
    BUILD_ID_FILE=${PF_SRC_DIR}/conf/build_id

    if [ -n "${CI_COMMIT_TAG}" ]; then
        TAG_OR_BRANCH_NAME=${CI_COMMIT_TAG}
    elif [ -n "${CI_COMMIT_REF_SLUG}" ]; then
        TAG_OR_BRANCH_NAME=${CI_COMMIT_REF_SLUG}
    else
        TAG_OR_BRANCH_NAME=localdev
    fi

    declare -p TAG_OR_BRANCH_NAME
}

write_build_id() {
    echo "TAG_OR_BRANCH_NAME=${TAG_OR_BRANCH_NAME}" > ${BUILD_ID_FILE}
    cat ${BUILD_ID_FILE}
}

log_section "Configure and check"
configure_and_check

log_section "Write build ID"
write_build_id
