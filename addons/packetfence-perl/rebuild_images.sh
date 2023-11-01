#!/bin/bash
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
# remove last component of path using bash susbtitution parameters
PF_SRC_DIR=${SCRIPT_DIR%/addons*}

# source variables from other files
# tr is to remove spaces between "="
source <(grep 'KNK_REGISTRY_URL' ${PF_SRC_DIR}/config.mk | tr -d ' ')
source <(grep 'LOCAL_REGISTRY' ${PF_SRC_DIR}/config.mk | tr -d ' ')
#source ${PF_SRC_DIR}/conf/build_id

log_section() {
    printf '=%.-1s' {1..72} ; printf "\n"
    printf "=\t%s\n" "" "$@" ""
}

configure_and_check() {
    
    # find all directories with Dockerfile
    # excluding non necessary images
    DOCKERFILE_DIRS=$(find ${PF_SRC_DIR} -type f -name "Dockerfile" \
                          -not -path "*/pfdebian/*" \
                          -not -path "*/radiusd/*" \
                          -not -path "*/kaniko-build/*" \
                          -not -path "*/packetfence-perl/*" \
                          -not -path "*/proxysql/*" \
                          -not -path "*/fingerbank-db/*" \
                          -not -path "*/httpd.dispatcher/*" \
                          -not -path "*/httpd.admin_dispatcher/*" \
                          -not -path "*/pfqueue/*" \
                          -not -path "*/pfcmd/*" \
                          -printf "%P\n")

    for file in ${DOCKERFILE_DIRS}; do
        # check if pfdebian container is used
        ts=$(grep pfdebian ${PF_SRC_DIR}/${file} || true)

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

rebuild_base_image_pfdebian() {
  source  ${PF_SRC_DIR}/containers/systemd-service
  # build base image pfdebian using new package packetfence-perl

  grep -Fxq 'COPY /packetfence-perl_*.deb /mnt'  ${PF_SRC_DIR}/containers/pfdebian/Dockerfile || echo "COPY /packetfence-perl_*.deb /mnt" >>  ${PF_SRC_DIR}/containers/pfdebian/Dockerfile
  grep -Fxq 'RUN dpkg -i /mnt/packetfence-perl_*.deb'  ${PF_SRC_DIR}/containers/pfdebian/Dockerfile || echo "RUN dpkg -i /mnt/packetfence-perl_*.deb" >> ${PF_SRC_DIR}/containers/pfdebian/Dockerfile

  cp /mnt/packetfence-perl_*.deb ${PF_SRC_DIR}

  #log_section "Build pfdebian docker image "
  HTML_MOUNT=''
  build_base_images
  #tag image pfdebian
  docker tag  $LOCAL_REGISTRY/pfdebian:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/pfdebian:$TAG_OR_BRANCH_NAME

}

rebuild_images() {
  log_section "Build other image that are using pfsebian as base"
  python3 -u ${SCRIPT_DIR}/rebuild_images.py -im "${CONTAINERS_IMAGES[@]}" -sp  ${PF_SRC_DIR}/addons/dev-helpers/build-local-container.sh 

  for img in ${CONTAINERS_IMAGES}; do
  #  bash ${PF_SRC_DIR}/addons/dev-helpers/build-local-container.sh ${img}
    docker tag  $LOCAL_REGISTRY/${img}:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/${img}:$TAG_OR_BRANCH_NAME
  done

  #tag pfconnector image with pfconnector-client and pfconnector-server
  for image_pfconnector in  pfconnector-server pfconnector-client 
  do
    docker tag  $LOCAL_REGISTRY/pfconnector:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/$image_pfconnector:$TAG_OR_BRANCH_NAME
    docker tag  $LOCAL_REGISTRY/pfconnector:$TAG_OR_BRANCH_NAME $LOCAL_REGISTRY/$image_pfconnector:$TAG_OR_BRANCH_NAME
  done

}

restart_packetfence() {
  log_section "Restart all PF services"
#  /usr/local/pf/bin/pfcmd service pf restart
  echo "stop PF services"
  /usr/local/pf/bin/pfcmd service pf stop
  echo "stop packetfence-config"
  systemctl stop packetfence-config
  echo "start packetfence-config"
  systemctl start packetfence-config
  echo "start PF services"
  /usr/local/pf/bin/pfcmd service pf start

  log_section "Make sure all servises are started"
  i=1
  while [[ $i -lt 10 ]]; do
    ((i++))
    echo "--------------------$i----------------------"
    stopped_pf_services=$(/usr/local/pf/bin/pfcmd service pf status  | grep stopped | awk '{print $1}' | tr '\n' ',')
    IFS="," read -ra stopped_pf_services <<< "$stopped_pf_services"
    echo "stopped services: ${stopped_pf_services[@]}"
    number_stopped_pf_services=${#stopped_pf_services[@]}

    if [[ $number_stopped_pf_services -eq 0 ]]; then
      echo 'all pf services are started'
      /usr/local/pf/bin/pfcmd service pf status
      break
    else
      for service in "${stopped_pf_services[@]}"
      do 
        echo "trying to start service: $service"
        CONTAINER_NAME="${service%.service}"
        CONTAINER_NAME=" ${CONTAINER_NAME#packetfence-}"
        systemctl stop $service || true;
        docker rm $CONTAINER_NAME || true;
        systemctl start $service || true;
      done
      continue
    fi

    echo "Some services did not started correctly"
    /usr/local/pf/bin/pfcmd service pf status
    exit 1
  done
}

configure_and_check

rebuild_base_image_pfdebian

rebuild_images

restart_packetfence

#log_section "Clean docker cash"
#docker system prune -f
