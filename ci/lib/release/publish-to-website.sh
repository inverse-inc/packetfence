#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}
get_pf_release


configure_and_check() {
    RESULT_DIR=${PF_SRC_DIR}/website
    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}

    # when making a release CI_COMMIT_TAG is defined
    if [ -n "${CI_COMMIT_TAG}" ]; then
        BRANCH_TYPE=stable
    else
        BRANCH_TYPE=devel
    fi
    
    mkdir -vp $RESULT_DIR
    declare -p RESULT_DIR PF_MINOR_RELEASE BRANCH_TYPE
}

generate_full_upgrade_files() {
    for os in ${OS_SUPPORTED}; do
        echo ${PF_MINOR_RELEASE} > ${RESULT_DIR}/latest-${BRANCH_TYPE}-$os.txt
        cat ${RESULT_DIR}/latest-${BRANCH_TYPE}-$os.txt
    done
}

log_section "Configure and check"
configure_and_check

log_section "Generate full upgrade files"
generate_full_upgrade_files

log_section "Display artifacts"
tree ${RESULT_DIR}
