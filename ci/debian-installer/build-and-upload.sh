#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_VERSION=${PF_VERSION:-localtest}

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

ISO_NAME=PacketFence-ISO-${PF_VERSION}.iso

# upload
SF_RESULT_DIR=results/sf/${PF_VERSION}

upload_to_linode() {
    echo "Create directory packetfence-iso/${PF_VERSION}/"
    rclone mkdir --s3-provider="Ceph"  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID}  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY}  --s3-endpoint="${RCLONE_LINODE_URL}"  --s3-acl=public-read :s3:packetfence-iso/${PF_VERSION}/
    echo "rclone ${ISO_NAME} to packetfence-iso/${PF_VERSION}/" 
    rclone copyto  --s3-provider="Ceph"  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID}  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY}  --s3-endpoint="${RCLONE_LINODE_URL}"  --s3-acl=public-read  ${SF_RESULT_DIR}/${ISO_NAME} :s3:packetfence-iso/${PF_VERSION}/${ISO_NAME}
    echo "Add md5sum ${ISO_NAME} in ${ISO_NAME}.md5sums.txt"
    echo "`md5sum ${SF_RESULT_DIR}/${ISO_NAME} | cut -d ' ' -f 1` ${ISO_NAME}" | tee -a ${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt
    rclone copyto  --s3-provider="Ceph"  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID}  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY}  --s3-endpoint="${RCLONE_LINODE_URL}"  --s3-acl=public-read  ${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt :s3:packetfence-iso/${PF_VERSION}/${ISO_NAME}.md5sums.txt
    
}

mkdir -p ${SF_RESULT_DIR}

echo "===> Build ISO for release $PF_RELEASE"
docker run --rm -e PF_RELEASE=$PF_RELEASE -e ISO_OUT="${SF_RESULT_DIR}/${ISO_NAME}" -v `pwd`:/debian-installer debian:12 /debian-installer/create-debian-installer-docker.sh

echo "===> Upload to Linode"
upload_to_linode
