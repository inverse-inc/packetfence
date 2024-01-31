#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_VERSION=${PF_VERSION:-localtest}

PF_RELEASE="`echo $PF_RELEASE | sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g'`"

ISO_NAME=PacketFence-ISO-${PF_VERSION}.iso

# upload
SF_RESULT_DIR=results/sf/${PF_VERSION}

upload_to_linode() {
    # using rclone config
    rclone mkdir pfiso:packetfence-iso/${PF_VERSION}/
    rclone copyto ${SF_RESULT_DIR}/${ISO_NAME} pfiso:packetfence-iso/${PF_VERSION}/${ISO_NAME}
}

mkdir -p ${SF_RESULT_DIR}

echo "===> Build ISO for release $PF_RELEASE"
docker run --rm -e PF_RELEASE=$PF_RELEASE -e ISO_OUT="${SF_RESULT_DIR}/${ISO_NAME}" -v `pwd`:/debian-installer debian:11 /debian-installer/create-debian-installer-docker.sh

echo "===> Upload to Linode"
upload_to_linode
