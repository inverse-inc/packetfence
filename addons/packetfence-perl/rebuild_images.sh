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
                           -not -path "*/proxysql/*" \
                           -not -path "*/fingerbank-db/*" \
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
configure_and_check

source  ${PF_SRC_DIR}/containers/systemd-service
# build base image pfdebian using new package packetfence-perl

[ grep -Fxq 'COPY /packetfence-perl_*.deb /mnt'  ${PF_SRC_DIR}/containers/pfdebian/Dockerfile ] || echo "COPY /packetfence-perl_*.deb /mnt" >>  ${PF_SRC_DIR}/containers/pfdebian/Dockerfile
[ grep -Fxq 'RUN dpkg -i /mnt/packetfence-perl_*.deb'  ${PF_SRC_DIR}/containers/pfdebian/Dockerfile  ] || echo "RUN dpkg -i /mnt/packetfence-perl_*.deb" >> ${PF_SRC_DIR}/containers/pfdebian/Dockerfile

cp /mnt/packetfence-perl_*.deb ${PF_SRC_DIR}

#log_section "Build pfdebian docker image "
build_base_images
#tag image pfdebian
docker tag  $LOCAL_REGISTRY/pfdebian:$TAG_OR_BRANCH_NAME $KNK_REGISTRY_URL/pfdebian:$TAG_OR_BRANCH_NAME

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

log_section "Restart all PF services"
/usr/local/pf/bin/pfcmd service pf restart
#for i in api-frontend haproxy-admin pfperl-api  httpd.admin_dispatcher; do
#  /usr/local/pf/bin/pfcmd service $i restart
#done

log_section "Make sure that all servises are started"

i=1
while [[ $i -lt 10 ]]; do
  ((i++))
  stopped_pf_services=$(/usr/local/pf/bin/pfcmd service pf status  | grep stopped | awk '{print $1}' | tr '\n' ',')
  IFS="," read -ra stopped_pf_services <<< "$stopped_pf_services"
  echo $stopped_pf_services
  number_stopped_pf_services=${#stopped_pf_services[@]}

  if [[ $number_stopped_pf_services -eq 0 ]]; then
    echo 'all pf services are started'
    /usr/local/pf/bin/pfcmd service pf status
    break
  else
    for service in "${stopped_pf_services[@]}"
    do 
      echo "trying to start service: $service"
      systemctl stop $service || true;
      systemctl start $service || true;
    done
    continue
  fi

  echo "Some services did not started correctly"
  /usr/local/pf/bin/pfcmd service pf status
  exit 1
done

#log_section "Clean docker cash"
#docker system prune -f
