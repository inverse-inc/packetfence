#!/bin/bash
set -o nounset -o pipefail -o errexit

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

# Version handling
PF_VERSION=${PF_VERSION:-localtest}

# Fix PF version if maintenance branch to match tag format (e.g., maintenance/15.0 -> v15.0.0)
if [[ "$PF_VERSION" =~ ^maintenance\/([0-9]+\.[0-9]+)$ ]]; then
    PF_VERSION="v${BASH_REMATCH[1]}.0"
    echo "Maintenance branch detected, using version: $PF_VERSION"
elif [[ "$PF_VERSION" =~ ^.*\/.*$ ]]; then
    # Replace slashes with dashes for any other branch format
    PF_VERSION="$(echo $PF_VERSION | sed -r 's/\//-/g')"
    echo "Branch detected, using version: $PF_VERSION"
fi

# Get PF release version for package repository
PF_RELEASE=${PF_RELEASE:-$(cat "${PF_ROOT}/conf/pf-release")}
PF_RELEASE_VERSION="$(echo $PF_RELEASE | sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g')"

# ISO naming with -usb suffix for directory
ISO_NAME=PacketFence-USB-ISO-${PF_VERSION}.iso
UPLOAD_DIR=${PF_VERSION}-usb

# Results directory
SF_RESULT_DIR=${SCRIPT_DIR}/results/sf/${UPLOAD_DIR}

upload_to_linode() {
    echo "Create directory packetfence-iso/${UPLOAD_DIR}/"
    rclone mkdir --s3-provider="Ceph" \
        --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
        --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
        --s3-endpoint="${RCLONE_LINODE_URL}" \
        --s3-acl=public-read \
        :s3:packetfence-iso/${UPLOAD_DIR}/

    echo "rclone ${ISO_NAME} to packetfence-iso/${UPLOAD_DIR}/"
    rclone copyto --s3-provider="Ceph" \
        --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
        --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
        --s3-endpoint="${RCLONE_LINODE_URL}" \
        --s3-acl=public-read \
        ${SF_RESULT_DIR}/${ISO_NAME} :s3:packetfence-iso/${UPLOAD_DIR}/${ISO_NAME}

    echo "Add md5sum ${ISO_NAME} in ${ISO_NAME}.md5sums.txt"
    echo "$(md5sum ${SF_RESULT_DIR}/${ISO_NAME} | cut -d ' ' -f 1) ${ISO_NAME}" | tee -a ${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt

    rclone copyto --s3-provider="Ceph" \
        --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
        --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
        --s3-endpoint="${RCLONE_LINODE_URL}" \
        --s3-acl=public-read \
        ${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt :s3:packetfence-iso/${UPLOAD_DIR}/${ISO_NAME}.md5sums.txt
}

# Create results directory
mkdir -p ${SF_RESULT_DIR}

echo "===> Build USB Bootable ISO for release $PF_RELEASE (version: $PF_VERSION)"
echo "===> ISO will be uploaded to: packetfence-iso/${UPLOAD_DIR}/"

# Export variables for build script
export PF_VERSION
export PF_RELEASE
export PF_RELEASE_VERSION
export ISO_OUT="${SF_RESULT_DIR}/${ISO_NAME}"

# Run the build script
${SCRIPT_DIR}/build-usb-bootable-iso.sh

echo "===> Upload to Linode"
upload_to_linode

echo "===> Done! ISO available at: packetfence-iso/${UPLOAD_DIR}/${ISO_NAME}"
