#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}

command -v gh >/dev/null || { echo "gh CLI missing from image"; exit 1; }

configure_and_check() {
    GIT_USER_NAME=${GIT_USER_NAME:-}
    GIT_USER_MAIL=${GIT_USER_MAIL:-}
    GIT_USER_PASSWORD=${GIT_USER_PASSWORD:-}
    GIT_REPO=${GIT_REPO:-}
    GIT_CI_BRANCH=${GIT_CI_BRANCH:-}
    GIT_LOCAL_PATH=$(mktemp -d)

    # Validate required variables
    if [ -z "${GIT_USER_NAME}" ]; then
        echo "Error: GIT_USER_NAME is required"
        exit 1
    fi
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
    declare -p GIT_REPO GIT_REPO_PATH
}

setup_gh_auth() {
    log_subsection "Setup GitHub CLI authentication"
    # Set GH_TOKEN for gh CLI authentication
    export GH_TOKEN="${GIT_USER_PASSWORD}"

    # Configure git to use gh as credential helper
    gh auth setup-git

    # Configure git user for commits
    git config --global user.name "${GIT_USER_NAME}"
    git config --global user.email "${GIT_USER_MAIL}"
    git config --global push.autoSetupRemote true
}

clone_git_repository() {
    log_subsection "Clone git repository"
    if ! gh repo clone "${GIT_REPO_PATH}" "${GIT_LOCAL_PATH}" > /dev/null 2>&1; then
        echo "Error: Git clone failed for ${GIT_REPO}"
        echo "Please verify GIT_USER_PASSWORD (GitHub PAT) in Psono."
        echo "Possible causes: expired token, revoked token, or insufficient permissions."
        echo "Required PAT scopes: 'repo' for full repository access."
        exit 1
    fi
}

compare_files() {
    log_subsection "Compare files"
    local local_file="${PF_SRC_DIR}/$1"
    local upstream_file="${GIT_LOCAL_PATH}/$2"
    declare -p local_file upstream_file
    if cmp --silent -- "${local_file}" "${upstream_file}"; then
        echo "files contents are identical, nothing to commit"
        exit 0
    else
        echo "files differ, need to commit changes"
        update_git_repository ${local_file} ${upstream_file}
    fi
}

update_git_repository() {
    # Chech the parameters.
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 <src_file> <dst_file>"
      exit 1
    fi

    local src_file=$1
    local dst_file=$2
    local date_now=$(date +"%Y-%m-%d %H:%M:%S")
    local commit_message="Automatic update ${date_now}"

    # Check the branch exists or not.
    if git -C ${GIT_LOCAL_PATH} ls-remote --exit-code --heads origin "${GIT_CI_BRANCH}" > /dev/null 2>&1; then
        # Skip commit
        echo "Skip commit, branch '${GIT_CI_BRANCH}' already exists."
    else
        log_subsection "Commit and push changes"
        cp -v ${src_file} ${dst_file}

        git -C ${GIT_LOCAL_PATH} checkout -b "${GIT_CI_BRANCH}"
        git -C ${GIT_LOCAL_PATH} add ${dst_file}
        git -C ${GIT_LOCAL_PATH} commit -am "${commit_message}"

        log_subsection "Push branch"
        git -C ${GIT_LOCAL_PATH} push --set-upstream origin "${GIT_CI_BRANCH}"
        echo "Branch '${GIT_CI_BRANCH}' pushed successfully."
    fi
}

cleanup() {
    rm -rf "${GIT_LOCAL_PATH:-}"
}
trap cleanup EXIT

log_section "Configure and check"
configure_and_check

log_section "Publish to git repository"
clone_git_repository
compare_files $1 $2
