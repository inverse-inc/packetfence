#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_VERSION=${PF_VERSION:-localtest}
PF_RELEASE=${PF_RELEASE:-12.0}

# Fix PF version if maintenance to match tag
if [[ "$PF_VERSION" =~ ^maintenance\/([0-9]+\.[0-9]+)$ ]];
then
  PF_VERSION=v;
  PF_VERSION+=${BASH_REMATCH[1]};
  PF_VERSION+=.0;
  echo "Maintenance Branch detected, try to match tag version with PF version = $PF_VERSION"
elif [[ "$PF_VERSION" =~ ^.*\/.*$ ]];
then
  PF_VERSION="`echo $PF_VERSION | sed -r 's/\//-/g'`"
fi

PF_RELEASE="`echo $PF_RELEASE | sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g'`"

ISO_NAME=PacketFence-USB-Bootable-${PF_VERSION}.iso

# Upload settings
SF_RESULT_DIR=results/sf/${PF_VERSION}

upload_to_linode() {
    echo "Create directory packetfence-iso-usb/${PF_VERSION}/"
    rclone mkdir --s3-provider="Ceph" --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} --s3-endpoint="${RCLONE_LINODE_URL}" --s3-acl=public-read :s3:packetfence-iso-usb/${PF_VERSION}/
    
    echo "rclone ${ISO_NAME} to packetfence-iso-usb/${PF_VERSION}/" 
    rclone copyto --s3-provider="Ceph" --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} --s3-endpoint="${RCLONE_LINODE_URL}" --s3-acl=public-read ${SF_RESULT_DIR}/${ISO_NAME} :s3:packetfence-iso-usb/${PF_VERSION}/${ISO_NAME}
    
    echo "Add sha256sum ${ISO_NAME} in ${ISO_NAME}.sha256sums.txt"
    echo "`sha256sum ${SF_RESULT_DIR}/${ISO_NAME} | cut -d ' ' -f 1` ${ISO_NAME}" | tee -a ${SF_RESULT_DIR}/${ISO_NAME}.sha256sums.txt
    rclone copyto --s3-provider="Ceph" --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} --s3-endpoint="${RCLONE_LINODE_URL}" --s3-acl=public-read ${SF_RESULT_DIR}/${ISO_NAME}.sha256sums.txt :s3:packetfence-iso-usb/${PF_VERSION}/${ISO_NAME}.sha256sums.txt
    
    echo "Add md5sum ${ISO_NAME} in ${ISO_NAME}.md5sums.txt"
    echo "`md5sum ${SF_RESULT_DIR}/${ISO_NAME} | cut -d ' ' -f 1` ${ISO_NAME}" | tee -a ${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt
    rclone copyto --s3-provider="Ceph" --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} --s3-endpoint="${RCLONE_LINODE_URL}" --s3-acl=public-read ${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt :s3:packetfence-iso-usb/${PF_VERSION}/${ISO_NAME}.md5sums.txt
}

mkdir -p ${SF_RESULT_DIR}

echo "===> Build USB Bootable ISO for release $PF_RELEASE"
docker run --rm --privileged \
    -e PF_RELEASE=$PF_RELEASE \
    -e PF_VERSION=$PF_VERSION \
    -e ISO_OUT="${SF_RESULT_DIR}/${ISO_NAME}" \
    -v `pwd`:/usb-bootable-iso \
    debian:12 \
    /usb-bootable-iso/build-usb-bootable-iso-docker.sh

echo "===> Upload to Linode"
upload_to_linode

echo "===> Build and upload completed!"
echo "ISO: ${SF_RESULT_DIR}/${ISO_NAME}"
echo "Size: $(du -h ${SF_RESULT_DIR}/${ISO_NAME} | cut -f1)"
