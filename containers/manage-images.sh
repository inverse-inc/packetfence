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

function proxy_config_systemd {
    service_name=$1
    HTTP_PROXY=${HTTP_PROXY:-}
    HTTPS_PROXY=${HTTPS_PROXY:-}
    NO_PROXY=${NO_PROXY:-}
    no_proxy=${no_proxy:-}
    http_proxy=${http_proxy:-}
    https_proxy=${https_proxy:-}

    # Check if HTTP_PROXY and HTTPS_PROXY environment variables exist
    if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$NO_PROXY" ] || [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$no_proxy" ]; then

        SERVICE_FILE=$(systemctl show -p FragmentPath --value "$service_name")
        if [ -z "$SERVICE_FILE" ]; then
            echo "Service not found: $service_name"
            exit 1
        fi

        # Check if [Service] section exists
        if grep -q "\[Service\]" "$SERVICE_FILE"; then
            config_count=()
            # Check if HTTP_PROXY already exist in [Service] section
            if ! grep -q "Environment=.*HTTP_PROXY" "$SERVICE_FILE" && ([ -n "$HTTP_PROXY" ] || [ -n "$http_proxy" ]); then
                # Add HTTP_PROXY to [Service] section
                [[ -n "${http_proxy}" ]] && HTTP_PROXY=$http_proxy
                sed -i '/\[Service\]/a Environment="HTTP_PROXY='$HTTP_PROXY'"' "$SERVICE_FILE"
                config_count+=("HTTP_PROXY=$HTTP_PROXY")
            fi	

            # Check if HTTPS_PROXY already exist in [Service] section
            if ! grep -q "Environment=.*HTTPS_PROXY" "$SERVICE_FILE" && ([ -n "$HTTPS_PROXY" ] || [ -n "$https_proxy" ]); then
                # Add  HTTPS_PROXY to [Service] section
                [[ -n "${https_proxy}" ]] && HTTPS_PROXY=$https_proxy
                sed -i '/\[Service\]/a Environment="HTTPS_PROXY='$HTTPS_PROXY'"' "$SERVICE_FILE"
                config_count+=("HTTPS_PROXY="${HTTPS_PROXY})
            fi


            # Check if NO_PROXY already exist in [Service] section
            if ! grep -q "Environment=.*NO_PROXY" "$SERVICE_FILE" && ([ -n "$NO_PROXY" ] || [ -n "$no_proxy" ]); then
                # Add NO_PROXY to [Service] section
                [[ -n "${no_proxy}" ]] && NO_PROXY=$no_proxy
                sed -i '/\[Service\]/a Environment="NO_PROXY='$NO_PROXY'"' "$SERVICE_FILE"
                config_count+=("NO_PROXY=$NO_PROXY")
            fi

        if [ ${#config_count[@]} -ne 0 ]; then

                # Reload systemd configuration
                systemctl daemon-reload

                # Restart Docker service
                systemctl restart $service_name

                printf "Next proxy configuration were added to $service_name service in [Service] section, \n systemd docker file $SERVICE_FILE \n"
                printf '%s\n' "${config_count[@]}"
            else
                printf "The proxy configuration already exist in [Service] section. No changes made. \n"
            fi
        else
            printf "Error: [Service] section not found in $SERVICE_FILE. \n"
        fi
    fi
}


configure_and_check() {
    # yes=default
    CLEANUP_IMAGES=${CLEANUP_IMAGES:-yes}

    # find all directories with Dockerfile
    # excluding non necessary images
    DOCKERFILE_DIRS=$(find ${SCRIPT_DIR} -type f -name "Dockerfile" \
                           -not -path "*/pfdebian/*" \
                           -not -path "*/radiusd/*" \
                           -not -path "*/pfconnector-*/*" \
                           -not -path "*/kaniko-build/*" \
                           -not -path "*/packetfence-perl/*" \
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
    RETRY_LIMIT=2
    for img in ${CONTAINERS_IMAGES}; do
        for attempt in $(seq 1 $RETRY_LIMIT); do
            docker pull -q ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME}
            if [ $? -eq 0 ]; then
                break
            else
                if [ $attempt -le $RETRY_LIMIT ]; then
                    sleep 3
                    echo "Retry downloading image: ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME}"
                else
                    echo "Failed downloading image: ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME}"
                fi
            fi
        done
    done
    echo "$(date) - Pull of images finished"
}

tag_images() {
    for img in ${CONTAINERS_IMAGES}; do
	docker tag ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME} ${LOCAL_REGISTRY}/${img}:${TAG_OR_BRANCH_NAME}
#	docker tag ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME} ${img}:latest
# 	docker tag ${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME} ${LOCAL_REGISTRY}/${img}:latest
    done

    # The pfconnector-server and pfconnector-client images point to the local pfconnector image
    docker tag ${LOCAL_REGISTRY}/pfconnector:${TAG_OR_BRANCH_NAME} ${LOCAL_REGISTRY}/pfconnector-server:${TAG_OR_BRANCH_NAME}
    docker tag ${LOCAL_REGISTRY}/pfconnector:${TAG_OR_BRANCH_NAME} ${LOCAL_REGISTRY}/pfconnector-client:${TAG_OR_BRANCH_NAME}

    echo "$(date) - Tag of images finished"
}

cleanup_images() {
    if [ "$CLEANUP_IMAGES" = "yes" ]; then
        if delete_images; then
            echo "$(date) - Previous images cleaned"
        else
            echo "$(date) - Cleanup of outdated docker images has failed"
        fi
    else
        echo "$(date) - Cleanup of Docker images disabled"
    fi
}

delete_images() {
    # ID of images which contain "packetfence" (in repository or tag)
    # and don't match TAG_OR_BRANCH_NAME store in conf/build_id
    # uniq to remove duplicated ID due to local and remote tags
    PREVIOUS_IMAGES=$(docker images --format "{{.Repository}};{{.ID}};{{.Tag}}" \
                              | grep "packetfence" \
                              | grep -v ${TAG_OR_BRANCH_NAME} \
                              | cut -d ';' -f 2 | uniq)

    if [ -n "$PREVIOUS_IMAGES" ]; then
	# -f is necessary because images are tagged locally and remotely (registry)
	docker rmi ${PREVIOUS_IMAGES} -f > /dev/null 2>&1
    fi

    # Remove all dangling images, images not referenced by any container are kept
    docker image prune -f > /dev/null 2>&1
}

proxy_config_systemd docker

configure_and_check

pull_images

tag_images

cleanup_images
