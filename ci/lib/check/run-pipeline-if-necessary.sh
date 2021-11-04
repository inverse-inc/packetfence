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
    CI_PROJECT_ID=${CI_PROJECT_ID:-}
    CI_COMMIT_REF_NAME=${CI_COMMIT_REF_NAME:-}

    COMMIT_REF_NAME_ENCODED=$(urlencode "$CI_COMMIT_REF_NAME")
    COMMIT_SHA=$(git rev-parse HEAD~0)
    
    # get SHA of latest pipeline scheduled with status=succes for that branch
    SHA_LATEST_PIPELINE=$(curl -s "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines?status=success&source=schedule&ref=${COMMIT_REF_NAME_ENCODED}" | jq -r '.[0].sha')

    RUN_PIPELINE=yes

    # We don't want to run a new pipeline if:
    # latest pipeline scheduled with identical SHA was a success
    if [ "$SHA_LATEST_PIPELINE" = "$COMMIT_SHA" ]; then
        echo "Latest pipeline scheduled on that branch for $COMMIT_SHA succeed"
        echo "No need to re-run a pipeline"
        RUN_PIPELINE=no
    fi

    declare -p COMMIT_SHA SHA_LATEST_PIPELINE
    declare -p RUN_PIPELINE
}

set_exit_code() {
    if [ "$RUN_PIPELINE" = "yes" ]; then
        echo "We need to run a pipeline"
        exit 0
    else
        # GitLab job will failed and prevent execution of next job
        echo "No need to run a pipeline"
        exit 1
    fi
}


log_section "Configure and check"
configure_and_check

log_section "Set exit code"
set_exit_code
