#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/conf/build_id

source /usr/local/pf/addons/functions/helpers.functions

cd /usr/local/pf/

main_splitter

# Only the services running in a container can be committed, some images
# (radiusd-auth, pfqueue, ...) are not used as a container on this server
function output_running_containers {
  docker ps --format '{{.Names}} {{.Image}}' | awk '$2 ~ /^packetfence\// { print "- " $1 }' | sort
}

img_name="${1:-}"
if [ -z "$img_name" ]; then
  echo "Unspecified container name"
  
  sub_splitter

  echo "The following containers can be used with this tool:"
  output_running_containers

  exit 1
fi

if ! docker container inspect "$img_name" > /dev/null 2>&1; then
  echo "No container named $img_name on this server: it is not started or the service doesn't run in a container"

  sub_splitter

  echo "The following containers can be used with this tool:"
  output_running_containers

  exit 1
fi

tag_name=packetfence/$img_name:$TAG_OR_BRANCH_NAME

docker commit $img_name $tag_name > /dev/null

echo "Updated local container image $img_name -> $tag_name"

