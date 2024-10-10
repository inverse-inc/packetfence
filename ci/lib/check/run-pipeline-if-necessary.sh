#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}

# GitLab API: https://docs.gitlab.com/ee/api/

configure_and_check() {
    CI_PROJECT_ID=${CI_PROJECT_ID:-}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    CI_COMMIT_REF_NAME=${CI_COMMIT_REF_NAME:-}
    GITLAB_API_TOKEN=${GITLAB_API_TOKEN:-}

    COMMIT_REF_NAME_ENCODED=$(urlencode "$CI_COMMIT_REF_NAME")
    COMMIT_SHA=$(git rev-parse HEAD~0)

    # if no token defined, we die
    [ -n "${GITLAB_API_TOKEN}" ] || die "not set: GITLAB_API_TOKEN"

    TOKEN_ERROR_DESC=$(curl --header "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" \
                               -s "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}" \
                              | jq -r '.error_description')

    if [ "$TOKEN_ERROR_DESC" != null ]; then
        die "Error $TOKEN_ERROR_DESC"
    fi

    # get SHA of latest pipeline scheduled with status=succes for that branch
    SHA_LATEST_PIPELINE=$(curl --header "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" \
                               -s "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines?status=success&source=schedule&ref=${COMMIT_REF_NAME_ENCODED}" \
                              | jq -r '.[0].sha')

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

cancel_pipeline() {
    curl --request POST \
         --header "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" \
         -s "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/cancel" \
         | jq -r '.status'
}

define_next_action() {
    if [ "$RUN_PIPELINE" = "yes" ]; then
        echo "We need to run a pipeline"
        exit 0
    else
        echo "No need to run a pipeline, cancelling pipeline"
        if [ $(cancel_pipeline) = "canceled" ]; then
            echo "Pipeline canceled"
            exit 0
        else
            echo "Unable to cancel pipeline"
            # job will failed and pipeline will be stopped
            exit 1
        fi
    fi
}

log_section "Configure and check"
configure_and_check

log_section "Define next action"
define_next_action
