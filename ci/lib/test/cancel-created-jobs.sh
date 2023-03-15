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
    GITLAB_API_TOKEN=${GITLAB_API_TOKEN:-}

    [ -n "${GITLAB_API_TOKEN}" ] || die "not set: GITLAB_API_TOKEN"
}

get_created_jobs() {
    curl --header "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" \
         -s "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/jobs?scope[]=pending&per_page=100" \
        | jq -r '.[].id'
}

cancel_job() {
    local job_id=$1
    curl --request POST \
         --header "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" \
         -s "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/jobs/${job_id}/cancel" \
         | jq -r '.status'
}

cancel_jobs() {
    jobs_id=$(get_created_jobs)
    if [ -z "$jobs_id" ]; then
	echo "No jobs to cancel"
    else
	for job_id in $jobs_id; do
            if [ $(cancel_job $job_id) = "canceled" ]; then
		echo "$job_id canceled"
            else
		echo "Unable to cancel $job_id"
            fi
	done
    fi
}

log_section "Configure and check"
configure_and_check

log_section "Cancelling jobs not started"
cancel_jobs
