#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/functions/helpers.functions

cd /usr/local/pf/

main_splitter

name="${1:-}"
if [ -z "$name" ]; then
  echo "Unspecified container name"
  
  sub_splitter

  echo "The following images can be used with this tool:"
  output_all_container_images

  exit 1
fi

dockerfile=containers/$name/Dockerfile

if ! [ -f $dockerfile ]; then
  echo "'$name' is not a valid container name."

  sub_splitter

  echo "The following images can be built using this tool:"
  output_all_container_images

  exit 1
fi

source /usr/local/pf/conf/build_id

img_name=packetfence/$name:$TAG_OR_BRANCH_NAME

echo "Building image $img_name"

sub_splitter

docker build -t $img_name \
  --build-arg=BUILD_PFAPPSERVER_VUE=yes \
  --build-arg=KNK_REGISTRY_URL=ghcr.io/inverse-inc/packetfence \
  --build-arg=IMAGE_TAG=$TAG_OR_BRANCH_NAME \
  -f containers/$name/Dockerfile .

main_splitter

echo "New image build from $dockerfile -> $img_name"
