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

# The image of the container, it can be shared by several containers (ex: ntlm-auth-api-<domain>)
image=$(docker container inspect -f '{{.Config.Image}}' "$img_name" 2> /dev/null || true)
if [[ "$image" != packetfence/* ]]; then
  echo "No PacketFence container named $img_name on this server: it is not started or the service doesn't run in a container"

  sub_splitter

  echo "The following containers can be used with this tool:"
  output_running_containers

  exit 1
fi

# Keep the repository of the image and replace its tag (the tag is after the last colon unless it is part of the registry)
repository=$image
if [[ "${image##*/}" == *:* ]]; then
  repository=${image%:*}
fi
tag_name=$repository:$TAG_OR_BRANCH_NAME

# before the commit, which moves the tag to the new image
shared=$(docker ps --format '{{.Names}} {{.Image}}' | awk -v name="$img_name" -v image="$image" '$1 != name && $2 == image { printf " %s", $1 }')

docker commit "$img_name" "$tag_name" > /dev/null

echo "Updated local container image $img_name -> $tag_name"

if [ -n "$shared" ]; then
  echo "This image is also used by:$shared"
fi

