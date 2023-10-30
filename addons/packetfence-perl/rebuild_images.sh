#!/bin/bash
#set -o nounset -o pipefail -o errexit

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
# remove last component of path using bash susbtitution parameters
PF_SRC_DIR=${SCRIPT_DIR%/addons*}

# source variables from other files
# tr is to remove spaces between "="
source <(grep 'KNK_REGISTRY_URL' ${PF_SRC_DIR}/config.mk | tr -d ' ')
source <(grep 'LOCAL_REGISTRY' ${PF_SRC_DIR}/config.mk | tr -d ' ')
#source ${PF_SRC_DIR}/conf/build_id

configure_and_check() {
    
    # find all directories with Dockerfile
    # excluding non necessary images
    DOCKERFILE_DIRS=$(find ${PF_SRC_DIR} -type f -name "Dockerfile" \
                           -not -path "*/pfdebian/*" \
                           -not -path "*/radiusd/*" \
                           -not -path "*/kaniko-build/*" \
                           -not -path "*/packetfence-perl/*" \
                           -not -path "*/fingerbank-db/*" \
                           -printf "%P\n")

    for file in ${DOCKERFILE_DIRS}; do
        # check if pfdebian container is used
        ts=$(grep pfdebian ${PF_SRC_DIR}/${file})

        if [ ! -z "$ts" ] 
        then 
          #remove prefix
          CONTAINER_IMAGE="${file%/Dockerfile}"
          #remove suffix
          CONTAINER_IMAGE=" ${CONTAINER_IMAGE#containers/}"
          CONTAINERS_IMAGES+=" ${CONTAINER_IMAGE}"
        fi
        
    done

    echo "$(date) - Images detected:"
    for img in ${CONTAINERS_IMAGES}; do
        echo "- $img"
    done
}
configure_and_check

source  ${PF_SRC_DIR}/containers/systemd-service
# build base image pfdebian using new package packetfence-perl
echo "COPY /packetfence-perl_*.deb /mnt" >>  ${PF_SRC_DIR}/containers/pfdebian/Dockerfile
echo "RUN dpkg -i /mnt/packetfence-perl_*.deb" >> ${PF_SRC_DIR}/containers/pfdebian/Dockerfile
cp /mnt/packetfence-perl_*.deb ${PF_SRC_DIR}

#build_base_images
#tag image pfdebian
#docker tag  $LOCAL_REGISTRY/pfdebian:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/pfdebian:$TAG_OR_BRANCH_NAME

python3 ${SCRIPT_DIR}/rebuild_images.py -im "${CONTAINERS_IMAGES[@]}" -sp  ${PF_SRC_DIR}/addons/dev-helpers/build-local-container.sh 

for img in ${CONTAINERS_IMAGES}; do
#  bash ${PF_SRC_DIR}/addons/dev-helpers/build-local-container.sh ${img}
  docker tag  $LOCAL_REGISTRY/${img}:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/${img}:$TAG_OR_BRANCH_NAME
done

#tag pfconnector image with pfconnector-client and pfconnector-server
docker tag  $LOCAL_REGISTRY/pfconnector:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/pfconnector-client:$TAG_OR_BRANCH_NAME
docker tag  $LOCAL_REGISTRY/pfconnnector:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/pfconnector-server:$TAG_OR_BRANCH_NAME

log_section "Start all PF services"
/usr/local/pf/bin/pfcmd service pf restart
#for i in api-frontend haproxy-admin pfperl-api  httpd.admin_dispatcher; do
#  /usr/local/pf/bin/pfcmd service $i restart
#done
