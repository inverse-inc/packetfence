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

generate_material() {
    echo "Make config files available to start pfconfig container"
    make -C ${PF_SRC_DIR} configurations
    make -C ${PF_SRC_DIR} conf/unified_api_system_pass
    make -C ${PF_SRC_DIR} conf/system_init_key
    make -C ${PF_SRC_DIR} conf/local_secret

    echo "Starting ${CONTAINER_NAME} container"
    docker run --detach --name=${CONTAINER_NAME} --rm -e PFCONFIG_PROTO=unix \
           -e GIT_USER_NAME \
           -e GIT_USER_MAIL \
           -e GIT_USER_PASSWORD \
	   -e GIT_REPO \
	   -e CI_PIPELINE_ID \
           -v ${PF_SRC_DIR}/conf:/usr/local/pf/conf \
           -v ${PF_SRC_DIR}/addons/dev-helpers/bin:/usr/local/pf/addons/dev-helpers/bin \
           -v ${PF_SRC_DIR}/ci/lib:/usr/local/pf/ci/lib \
           -v ${PF_SRC_DIR}/config.mk:/usr/local/pf/config.mk \
           -v ${PF_SRC_DIR}/Makefile:/usr/local/pf/Makefile \
           ghcr.io/inverse-inc/packetfence/pfconfig:${IMAGE_TAG}

    echo "Let some time to container to start"
    sleep 20

    echo "Generating material.html file"
    docker exec ${CONTAINER_NAME} /usr/bin/make material

    echo "Publishing material.html to git if necessary"
    docker exec ${CONTAINER_NAME} /usr/local/pf/ci/lib/release/publish-to-git.sh ${SRC_FILE} ${DST_FILE}
}

cleanup() {
    docker stop ${CONTAINER_NAME}
}

trap cleanup EXIT

log_section "Configure and check"
configure_and_check

log_section "Generate material"
generate_material

