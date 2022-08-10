#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
# remove last component of path using bash susbtitution parameters
PF_SRC_DIR=${SCRIPT_DIR%/*}

# source variables from other files
# tr is to remove spaces between "="
source <(grep 'KNK_REGISTRY_URL' ${PF_SRC_DIR}/config.mk | tr -d ' ')
source <(grep 'LOCAL_REGISTRY' ${PF_SRC_DIR}/config.mk | tr -d ' ')
source ${PF_SRC_DIR}/conf/build_id

configure_and_check() {
    # yes=default
    CLEANUP_IMAGES=${CLEANUP_IMAGES:-yes}

    # ID of images which doesn't match TAG_OR_BRANCH_NAME store in conf/build_id
    # uniq to remove duplicated ID due to local and remote tags
    # || true is to handle first installation case: no images and grep exit with 1
    PREVIOUS_IMAGES=$(docker images --format "{{.ID}}: {{.Tag}}" \
                          | { grep -v "${TAG_OR_BRANCH_NAME}" || true; } \
                          | cut -d ':' -f 1 | uniq)

    # find all directories with Dockerfile
    # excluding non necessary images
    DOCKERFILE_DIRS=$(find ${SCRIPT_DIR} -type f -name "Dockerfile" \
                           -not -path "*/pfdebian/*" \
                           -not -path "*/radiusd/*" \
                           -not -path "*/pfconnector-*/*" \
                           -printf "%P\n")

    for file in ${DOCKERFILE_DIRS}; do
	# remove /Dockerfile suffix
	CONTAINERS_IMAGES+=" ${file%/Dockerfile}"
    done
    
    echo "$(date) - Images detected:"
    for img in ${CONTAINERS_IMAGES}; do
	echo "- $img"
    done
}

pull_images() {
    for img in ${CONTAINERS_IMAGES}; do
	docker pull -q ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME}
    done
    echo "$(date) - Pull of images finished"
}

tag_images() {
    for img in ${CONTAINERS_IMAGES}; do
	docker tag ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME} ${LOCAL_REGISTRY}/${img}:${TAG_OR_BRANCH_NAME}
    done

    # The pfconnector-server and pfconnector-client images point to the local pfconnector image
    docker tag ${LOCAL_REGISTRY}/pfconnector:${TAG_OR_BRANCH_NAME} ${LOCAL_REGISTRY}/pfconnector-server:${TAG_OR_BRANCH_NAME}
    docker tag ${LOCAL_REGISTRY}/pfconnector:${TAG_OR_BRANCH_NAME} ${LOCAL_REGISTRY}/pfconnector-client:${TAG_OR_BRANCH_NAME}

    echo "$(date) - Tag of images finished"
}

cleanup_images() {
    if [ "$CLEANUP_IMAGES" = "yes" ]; then
        if [ -z "$PREVIOUS_IMAGES" ]; then
            echo "$(date) - Nothing to cleanup"
        else
            if delete_images; then
                echo "$(date) - Previous images cleaned"
            else
                echo "$(date) - Cleanup has failed"
            fi
        fi
    else
        echo "$(date) - Cleanup of Docker images disabled"
    fi
}

delete_images() {
    docker rmi ${PREVIOUS_IMAGES} -f > /dev/null 2>&1
}

configure_and_check

pull_images

tag_images

cleanup_images
