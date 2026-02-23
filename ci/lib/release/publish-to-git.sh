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
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    GIT_USER_NAME=${GIT_USER_NAME:-John Doe}
    GIT_USER_MAIL=${GIT_USER_MAIL:-johndoe@example.com}
    GIT_USER_PASSWORD=${GIT_USER_PASSWORD:-secret}
    GIT_REPO=${GIT_REPO:-git.example.com/user/repo.git}
    GIT_CLONE_METHOD=${GIT_CLONE_METHOD:-https://}
    GIT_LOCAL_PATH=$(mktemp -d)

    GIT_REPO_URL=${GIT_CLONE_METHOD}${GIT_USER_NAME}:${GIT_USER_PASSWORD}@${GIT_REPO}
    
    generate_git_config
    declare -p GIT_REPO
}

generate_git_config() {
    git config --global user.name "${GIT_USER_NAME}"
    git config --global user.email "${GIT_USER_MAIL}"
    # to store credentials in memory for a short period of time
    git config --global credential.helper cache
    # set 'autoSetupRemote' in order to automatically set an upstream tracking branch
    git config --global push.autoSetupRemote true
}

clone_git_repository() {
    log_subsection "Clone git repository"
    git clone ${GIT_REPO_URL} ${GIT_LOCAL_PATH}
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
    log_subsection "Commit and push changes"
    local src_file=$1
    local dst_file=$2
    local git_ci_branch="ci-release-${CI_PIPELINE_ID}"
    local date_now=$(date +"%Y-%m-%d %H:%M:%S")
    local commit_message="Automatic update by pipeline ${CI_PIPELINE_ID} ${date_now}"

    cp -v ${src_file} ${dst_file}

    # Check the branch exists ot not.
    if git -C ${GIT_LOCAL_PATH} ls-remote --exit-code --heads origin "$git_ci_branch" > /dev/null 2>&1; then
        # Skip commit
        echo "Skip commit, branch '$git_ci_branch' already exists."
    else
        git -C ${GIT_LOCAL_PATH} checkout -b "$git_ci_branch"

        git -C ${GIT_LOCAL_PATH} add ${dst_file}
        git -C ${GIT_LOCAL_PATH} commit -am "${commit_message}"
        # will use credential helper, no need to specify again credentials
        git -C ${GIT_LOCAL_PATH} push
    fi
}

log_section "Configure and check"
configure_and_check

log_section "Publish to git repository"
clone_git_repository
compare_files $1 $2
