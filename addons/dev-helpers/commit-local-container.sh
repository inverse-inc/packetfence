#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/conf/build_id

source /usr/local/pf/addons/functions/helpers.functions

cd /usr/local/pf/

main_splitter

img_name="${1:-}"
if [ -z "$img_name" ]; then
  echo "Unspecified container name"
  
  sub_splitter

  echo "The following images can be used with this tool:"
  output_all_container_images

  exit 1
fi

tag_name=packetfence/$img_name:$TAG_OR_BRANCH_NAME

docker commit $img_name $tag_name > /dev/null

echo "Updated local container image $img_name -> $tag_name"

