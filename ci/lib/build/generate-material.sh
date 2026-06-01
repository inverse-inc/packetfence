#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}

python3 -c "import nacl" 2>/dev/null || { echo "pynacl missing from image"; exit 1; }
command -v gh >/dev/null || { echo "gh CLI missing from image"; exit 1; }
command -v docker >/dev/null || { echo "docker CLI missing from image"; exit 1; }

configure_and_check() {
    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}
    CI_COMMIT_REF_SLUG=${CI_COMMIT_REF_SLUG:-}
    SRC_FILE=${SRC_FILE:-}
    DST_FILE=${DST_FILE:-}
    CONTAINER_NAME=pfconfig_material

    if [ -n "${CI_COMMIT_TAG}" ]; then
        # release
        IMAGE_TAG=${CI_COMMIT_TAG}
    elif [ -n "${CI_COMMIT_REF_SLUG}" ]; then
        # all branches (maintenance included and devel)
        IMAGE_TAG=${CI_COMMIT_REF_SLUG}
    else
        IMAGE_TAG=localdev
    fi

    declare -p CI_COMMIT_TAG CI_COMMIT_REF_SLUG
    declare -p IMAGE_TAG
}

fetch_git_credentials_from_psono() {
    log_subsection "Fetch git credentials from Psono"
    # Psono configuration for website-pfcom credentials
    PSONO_WEBSITE_PFCOM_API_KEY_ID=${PSONO_WEBSITE_PFCOM_API_KEY_ID:-}
    PSONO_WEBSITE_PFCOM_API_SECRET_KEY=${PSONO_WEBSITE_PFCOM_API_SECRET_KEY:-}
    # Psono secret IDs (hardcoded - these are not secrets, just references)
    PSONO_WEBSITE_PFCOM_TOKEN="772cfb2e-4ef9-461b-9984-7a3ebe5694f9"
    PSONO_SCRIPT=${PF_SRC_DIR}/addons/packetfence-perl/psono.py

    if [ -z "${PSONO_WEBSITE_PFCOM_API_KEY_ID}" ] || [ -z "${PSONO_WEBSITE_PFCOM_API_SECRET_KEY}" ]; then
        echo "Error: Psono API keys are required"
        echo "Please set PSONO_WEBSITE_PFCOM_API_KEY_ID and PSONO_WEBSITE_PFCOM_API_SECRET_KEY in GitLab CI/CD variables"
        exit 1
    fi

    if [ ! -f "${PSONO_SCRIPT}" ]; then
        echo "Error: Psono script not found at ${PSONO_SCRIPT}"
        exit 1
    fi

    export GIT_USER_NAME=$(python3 "${PSONO_SCRIPT}" \
        --api_key_id="${PSONO_WEBSITE_PFCOM_API_KEY_ID}" \
        --api_key_secret_key="${PSONO_WEBSITE_PFCOM_API_SECRET_KEY}" \
        --secret_id="${PSONO_WEBSITE_PFCOM_TOKEN}" \
        --return_value=username)

    export GIT_USER_PASSWORD=$(python3 "${PSONO_SCRIPT}" \
        --api_key_id="${PSONO_WEBSITE_PFCOM_API_KEY_ID}" \
        --api_key_secret_key="${PSONO_WEBSITE_PFCOM_API_SECRET_KEY}" \
        --secret_id="${PSONO_WEBSITE_PFCOM_TOKEN}" \
        --return_value=password)

    export GIT_USER_MAIL="${GIT_USER_NAME}@inverse.ca"
    export GIT_CI_BRANCH="ci-release-${CI_PIPELINE_ID}"

    echo "Git credentials fetched from Psono"
}

generate_switches_json() {
    log_subsection "Generate switches.json via pfconfig sidecar"

    echo "Make config files available to start pfconfig container"
    make -C ${PF_SRC_DIR} configurations
    make -C ${PF_SRC_DIR} conf/unified_api_system_pass
    make -C ${PF_SRC_DIR} conf/system_init_key
    make -C ${PF_SRC_DIR} conf/local_secret
    mkdir -p ${PF_SRC_DIR}/result

    echo "Starting ${CONTAINER_NAME} container"
    docker run --detach --name=${CONTAINER_NAME} --rm -e PFCONFIG_PROTO=unix \
           -v ${PF_SRC_DIR}/conf:/usr/local/pf/conf \
           -v ${PF_SRC_DIR}/addons/dev-helpers/bin:/usr/local/pf/addons/dev-helpers/bin \
           -v ${PF_SRC_DIR}/ci/lib:/usr/local/pf/ci/lib \
           -v ${PF_SRC_DIR}/config.mk:/usr/local/pf/config.mk \
           -v ${PF_SRC_DIR}/Makefile:/usr/local/pf/Makefile \
           -v ${PF_SRC_DIR}/result:/usr/local/pf/result \
           ghcr.io/inverse-inc/packetfence/pfconfig:${IMAGE_TAG}

    echo "Let some time for the pfconfig daemon to be ready"
    sleep 20

    echo "Generating switches.json file"
    docker exec ${CONTAINER_NAME} /usr/bin/make material
}

cleanup_on_exit() {
    docker stop ${CONTAINER_NAME} >/dev/null 2>&1 || true
    unset GIT_USER_PASSWORD GIT_USER_NAME GIT_USER_MAIL GIT_CI_BRANCH || true
}

publish_and_pr() {
    echo "Publishing switches.json to packetfence site git repo ( https://github.com/akainverse/website-pfcom )"
    ${PF_SRC_DIR}/ci/lib/release/publish-to-git.sh ${SRC_FILE} ${DST_FILE}

    echo "Creating pull request"
    ${PF_SRC_DIR}/ci/lib/release/create-pr.sh
}

trap cleanup_on_exit EXIT

log_section "Configure and check"
configure_and_check

log_section "Fetch credentials"
fetch_git_credentials_from_psono

log_section "Generate material"
generate_switches_json

log_section "Publish material"
publish_and_pr
