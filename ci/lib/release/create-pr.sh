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
    GIT_USER_PASSWORD=${GIT_USER_PASSWORD:-}
    GIT_REPO=${GIT_REPO:-}
    GIT_CI_BRANCH=${GIT_CI_BRANCH:-}
    GIT_BASE_BRANCH=${GIT_BASE_BRANCH:-main}

    # Validate required variables
    if [ -z "${GIT_USER_PASSWORD}" ]; then
        echo "Error: GIT_USER_PASSWORD is required"
        exit 1
    fi
    if [ -z "${GIT_REPO}" ]; then
        echo "Error: GIT_REPO is required"
        exit 1
    fi
    if [ -z "${GIT_CI_BRANCH}" ]; then
        echo "Error: GIT_CI_BRANCH is required"
        exit 1
    fi

    # Extract repo path without hostname (e.g., akainverse/website-pfcom from github.com/akainverse/website-pfcom)
    GIT_REPO_PATH=$(echo "${GIT_REPO}" | cut -d'/' -f2-)

    setup_gh_auth
    declare -p GIT_REPO GIT_REPO_PATH GIT_CI_BRANCH GIT_BASE_BRANCH
}

setup_gh_auth() {
    log_subsection "Setup GitHub CLI authentication"
    # Set GH_TOKEN for gh CLI authentication
    export GH_TOKEN="${GIT_USER_PASSWORD}"
}

check_branch_exists() {
    log_subsection "Check if branch exists"
    if ! gh api "repos/${GIT_REPO_PATH}/branches/${GIT_CI_BRANCH}" > /dev/null 2>&1; then
        echo "Error: Branch '${GIT_CI_BRANCH}' does not exist on remote."
        echo "Please run publish-to-git.sh first to push the branch."
        exit 1
    fi
    echo "Branch '${GIT_CI_BRANCH}' exists."
}

check_pr_exists() {
    log_subsection "Check if PR already exists"
    local existing_pr
    existing_pr=$(gh pr list --repo "${GIT_REPO_PATH}" --head "${GIT_CI_BRANCH}" --json number --jq '.[0].number' 2>/dev/null || echo "")

    if [ -n "${existing_pr}" ]; then
        echo "PR #${existing_pr} already exists for branch '${GIT_CI_BRANCH}'."
        echo "PR URL: https://github.com/${GIT_REPO_PATH}/pull/${existing_pr}"
        echo "Skipping PR creation."
        exit 0
    fi
}

create_pull_request() {
    log_subsection "Create pull request"
    local date_now=$(date +"%Y-%m-%d %H:%M:%S")
    local pr_title="Automatic update ${date_now}"
    local pr_body="Automatic update from branch ${GIT_CI_BRANCH}"
    local pr_url

    pr_url=$(gh pr create \
        --repo "${GIT_REPO_PATH}" \
        --title "${pr_title}" \
        --body "${pr_body}" \
        --head "${GIT_CI_BRANCH}" \
        --base "${GIT_BASE_BRANCH}" 2>&1)

    if [[ "${pr_url}" =~ ^https://github\.com/.*/pull/[0-9]+$ ]]; then
        echo "Pull request created successfully: ${pr_url}"
    else
        echo "Error: Failed to create pull request"
        echo "Check GitHub PAT permissions and repository access."
        exit 1
    fi
}

log_section "Configure and check"
configure_and_check

log_section "Validate prerequisites"
check_branch_exists
check_pr_exists

log_section "Create pull request"
create_pull_request
