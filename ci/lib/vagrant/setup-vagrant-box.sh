#!/bin/bash
set -o nounset -o pipefail -o errexit

# Download the latest prebuilt vagrant box from Linode Object Storage and
# register it locally via `vagrant box add`.
#
# Required env vars:
#   BOX_NAME              e.g. pfdeb12dev
#   RCLONE_LINODE_URL     S3 endpoint, e.g. https://us-east-1.linodeobjects.com
#
# Optional env vars:
#   BUCKET                (default: packetfence-iso)
#   BUCKET_PREFIX         (default: vagrant)
#   VAGRANT_BOX_LINODE_URL  override derived public base URL (incl. bucket prefix)
#   PROVIDER              (default: libvirt)
#   VAGRANT_BOX_LOCAL_NAME  (default: inverse-inc/${BOX_NAME})
#   WORK_DIR              (default: /var/local/gitlab-runner/vagrant_img_cache)
#
# Usage:
#   BOX_NAME=pfdeb12dev RCLONE_LINODE_URL=https://us-east-1.linodeobjects.com \
#     ./setup-vagrant-box.sh

BUCKET=${BUCKET:-packetfence-iso}
BUCKET_PREFIX=${BUCKET_PREFIX:-vagrant}
# Derive public HTTPS base URL from the S3 endpoint (same logic as upload-to-linode.sh):
#   https://us-east-1.linodeobjects.com -> https://packetfence-iso.us-east-1.linodeobjects.com/vagrant
VAGRANT_BOX_LINODE_URL=${VAGRANT_BOX_LINODE_URL:-"${RCLONE_LINODE_URL/https:\/\//https://${BUCKET}.}/${BUCKET_PREFIX}"}

PROVIDER=${PROVIDER:-libvirt}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}}
WORK_DIR=${WORK_DIR:-/var/local/gitlab-runner/vagrant_img_cache}

BOX_FILENAME="${BOX_NAME}-${PROVIDER}.box"
VERSION_MARKER="${WORK_DIR}/${BOX_NAME}.version"

echo "===> Resolving latest box version for ${BOX_NAME}"
BOX_VERSION=$(curl -fsSL "${VAGRANT_BOX_LINODE_URL}/${BOX_NAME}/latest.txt" | tr -d '[:space:]')
echo "     Latest version: ${BOX_VERSION}"

# Skip download if the same version is already installed locally
if [ -f "${VERSION_MARKER}" ] && [ "$(cat "${VERSION_MARKER}")" = "${BOX_VERSION}" ]; then
    if vagrant box list | grep -qF "${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER},"; then
        echo "===> Box ${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER}) version ${BOX_VERSION} already present, skipping download"
        vagrant box list
        exit 0
    fi
fi

mkdir -p "${WORK_DIR}"

echo "===> Downloading ${BOX_FILENAME} (version ${BOX_VERSION})"
curl -fSL \
    "${VAGRANT_BOX_LINODE_URL}/${BOX_NAME}/latest/${BOX_FILENAME}" \
    -o "${WORK_DIR}/${BOX_FILENAME}"

echo "===> Downloading checksum"
curl -fSL \
    "${VAGRANT_BOX_LINODE_URL}/${BOX_NAME}/latest/${BOX_FILENAME}.md5sums.txt" \
    -o "${WORK_DIR}/${BOX_FILENAME}.md5sums.txt"

echo "===> Verifying checksum"
(cd "${WORK_DIR}" && md5sum -c "${BOX_FILENAME}.md5sums.txt")

echo "===> Removing any existing local box for ${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER})"
vagrant box remove "${VAGRANT_BOX_LOCAL_NAME}" --provider "${PROVIDER}" --all --force || true

echo "===> Adding box as ${VAGRANT_BOX_LOCAL_NAME}"
vagrant box add \
    --name "${VAGRANT_BOX_LOCAL_NAME}" \
    --provider "${PROVIDER}" \
    --force \
    "${WORK_DIR}/${BOX_FILENAME}"

echo "${BOX_VERSION}" > "${VERSION_MARKER}"

echo "===> Box registered successfully:"
vagrant box list
