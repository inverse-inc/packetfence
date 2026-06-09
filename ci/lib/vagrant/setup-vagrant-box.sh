#!/bin/bash
set -o nounset -o pipefail -o errexit

# Download the latest prebuilt vagrant box from Linode Object Storage and
# register it locally via `vagrant box add`.
#
# The bucket is private; all reads go through authenticated rclone.
#
# Required env vars:
#   BOX_NAME                 e.g. pfdeb12dev
#   RCLONE_LINODE_URL        S3 endpoint, e.g. https://us-ord-1.linodeobjects.com
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#
# Optional env vars:
#   BOX_VERSION             pin to this exact version (skips metadata.json resolution).
#                           Use this to match a version pinned in the vagrant inventory.
#   BUCKET                  (default: packetfence-vagrant-box)
#   PROVIDER                (default: libvirt)
#   VAGRANT_BOX_LOCAL_NAME  (default: inverse-inc/${BOX_NAME})
#   WORK_DIR                (default: /var/local/gitlab-runner/vagrant_img_cache)
#
# Usage:
#   BOX_NAME=pfdeb12dev RCLONE_LINODE_URL=https://us-ord-1.linodeobjects.com \
#     RCLONE_ACCESS_KEY_ID=... RCLONE_SECRET_ACCESS_KEY=... \
#     ./setup-vagrant-box.sh

BUCKET=${BUCKET:-packetfence-vagrant-box}
PROVIDER=${PROVIDER:-libvirt}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}}
WORK_DIR=${WORK_DIR:-/var/local/gitlab-runner/vagrant_img_cache}
BOX_VERSION=${BOX_VERSION:-}

VERSION_MARKER="${WORK_DIR}/${BOX_NAME}.version"

RCLONE_OPTS="--s3-provider=Ceph \
  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
  --s3-endpoint=${RCLONE_LINODE_URL}"

BOX_PREFIX=":s3:${BUCKET}/${BOX_NAME}"
METADATA_REMOTE="${BOX_PREFIX}/metadata.json"

echo "===> setup-vagrant-box.sh inputs"
echo "     BOX_NAME              = ${BOX_NAME}"
echo "     BOX_VERSION (pinned)  = ${BOX_VERSION:-<unset; will resolve via metadata.json>}"
echo "     PROVIDER              = ${PROVIDER}"
echo "     VAGRANT_BOX_LOCAL_NAME= ${VAGRANT_BOX_LOCAL_NAME}"
echo "     RCLONE_LINODE_URL     = ${RCLONE_LINODE_URL:-<unset>}"
echo "     BOX_PREFIX            = ${BOX_PREFIX}"
echo "     WORK_DIR              = ${WORK_DIR}"

echo "===> Probing bucket layout for ${BOX_NAME}"
# shellcheck disable=SC2086
rclone lsf ${RCLONE_OPTS} "${BOX_PREFIX}/" || echo "     (listing ${BOX_PREFIX}/ failed)"

if [ -n "${BOX_VERSION}" ]; then
    echo "===> Using pinned BOX_VERSION=${BOX_VERSION} (skipping metadata.json resolution)"
    # shellcheck disable=SC2086
    if ! rclone lsf ${RCLONE_OPTS} "${BOX_PREFIX}/${BOX_VERSION}.box" > /dev/null; then
        echo "ERROR: pinned .box not found at ${BOX_PREFIX}/${BOX_VERSION}.box"
        exit 1
    fi
else
    echo "===> Resolving latest box version for ${BOX_NAME}"
    # Newest entry is versions[0]; upload-to-linode.sh prepends on each build.
    META_BODY=$(mktemp)
    trap 'rm -f "${META_BODY}"' EXIT
    # shellcheck disable=SC2086
    if ! rclone copyto ${RCLONE_OPTS} "${METADATA_REMOTE}" "${META_BODY}"; then
        echo "ERROR: failed to fetch ${METADATA_REMOTE}"
        exit 1
    fi
    BOX_VERSION=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["versions"][0]["version"])' < "${META_BODY}")
    echo "     Latest version: ${BOX_VERSION}"
fi

# Box file matches the layout written by upload-to-linode.sh: <box>/<version>.box
BOX_FILENAME="${BOX_VERSION}.box"

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
# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} \
    "${BOX_PREFIX}/${BOX_FILENAME}" \
    "${WORK_DIR}/${BOX_FILENAME}"

echo "===> Downloading checksum"
# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} \
    "${BOX_PREFIX}/${BOX_FILENAME}.md5sums.txt" \
    "${WORK_DIR}/${BOX_FILENAME}.md5sums.txt"

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
