#!/bin/bash
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

# Version handling
PF_VERSION=${PF_VERSION:-localtest}
if [[ "$PF_VERSION" =~ ^maintenance\/([0-9]+\.[0-9]+)$ ]]; then
    PF_VERSION="v${BASH_REMATCH[1]}.0"
elif [[ "$PF_VERSION" == */* ]]; then
    PF_VERSION="${PF_VERSION//\//-}"
fi

PF_RELEASE=${PF_RELEASE:-$(< "${PF_ROOT}/conf/pf-release")}
PF_RELEASE_VERSION=$(sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g' <<< "$PF_RELEASE")

ISO_NAME=PacketFence-USB-ISO-${PF_VERSION}.iso
UPLOAD_DIR=${PF_VERSION}-usb
SF_RESULT_DIR=${SCRIPT_DIR}/results/sf/${UPLOAD_DIR}

# Common rclone options
RCLONE_OPTS="--s3-provider=Ceph --s3-access-key-id=${RCLONE_ACCESS_KEY_ID:-} --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY:-} --s3-endpoint=${RCLONE_LINODE_URL:-} --s3-acl=public-read"

upload_to_linode() {
    local bucket=":s3:packetfence-iso/${UPLOAD_DIR}"

    echo "Uploading to ${bucket}/"
    rclone mkdir ${RCLONE_OPTS} "${bucket}/"
    rclone copyto ${RCLONE_OPTS} "${SF_RESULT_DIR}/${ISO_NAME}" "${bucket}/${ISO_NAME}"

    md5sum "${SF_RESULT_DIR}/${ISO_NAME}" | cut -d' ' -f1 | xargs -I{} echo "{} ${ISO_NAME}" > "${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt"
    rclone copyto ${RCLONE_OPTS} "${SF_RESULT_DIR}/${ISO_NAME}.md5sums.txt" "${bucket}/${ISO_NAME}.md5sums.txt"
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
