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
#   WORK_DIR                (default: ~/vagrant_img_cache)
#   KEEP_BOX_ARCHIVE        keep the .box after unpacking (default: no)
#
# Usage:
#   BOX_NAME=pfdeb12dev RCLONE_LINODE_URL=https://us-ord-1.linodeobjects.com \
#     RCLONE_ACCESS_KEY_ID=... RCLONE_SECRET_ACCESS_KEY=... \
#     ./setup-vagrant-box.sh

BUCKET=${BUCKET:-packetfence-vagrant-box}
PROVIDER=${PROVIDER:-libvirt}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}}
WORK_DIR=${WORK_DIR:-${HOME}/vagrant_img_cache}
BOX_VERSION=${BOX_VERSION:-}

VERSION_MARKER="${WORK_DIR}/${BOX_NAME}.version"

# Drop the archive however we exit: beside the unpacked box it doubles each
# box's footprint, and on an ENOSPC failure it is what filled the volume.
META_BODY=""
ARCHIVE=""
on_exit() {
    rm -f ${META_BODY}
    [ "${KEEP_BOX_ARCHIVE:-no}" = yes ] || rm -f ${ARCHIVE} ${ARCHIVE:+${ARCHIVE}.md5sums.txt}
}
trap on_exit EXIT

# Configure rclone via env-var remote so credentials never appear on the
# command line (visible to `ps`, debug traces, etc.).
export RCLONE_CONFIG_S3_TYPE=s3
export RCLONE_CONFIG_S3_PROVIDER=Ceph
export RCLONE_CONFIG_S3_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID}
export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY}
export RCLONE_CONFIG_S3_ENDPOINT=${RCLONE_LINODE_URL}

BOX_PREFIX="s3:${BUCKET}/${BOX_NAME}"
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
rclone lsf "${BOX_PREFIX}/" || echo "     (listing ${BOX_PREFIX}/ failed)"

if [ -n "${BOX_VERSION}" ]; then
    echo "===> Using pinned BOX_VERSION=${BOX_VERSION} (skipping metadata.json resolution)"
    if ! rclone lsf "${BOX_PREFIX}/${BOX_VERSION}.box" > /dev/null; then
        echo "ERROR: pinned .box not found at ${BOX_PREFIX}/${BOX_VERSION}.box"
        exit 1
    fi
else
    echo "===> Resolving latest box version for ${BOX_NAME}"
    # Newest entry is versions[0]; upload-to-linode.sh prepends on each build.
    META_BODY=$(mktemp)
    if ! rclone copyto "${METADATA_REMOTE}" "${META_BODY}"; then
        echo "ERROR: failed to fetch ${METADATA_REMOTE}"
        exit 1
    fi
    BOX_VERSION=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["versions"][0]["version"])' < "${META_BODY}")
    echo "     Latest version: ${BOX_VERSION}"
fi

# Box file matches the layout written by upload-to-linode.sh: <box>/<version>.box
BOX_FILENAME="${BOX_VERSION}.box"
ARCHIVE="${WORK_DIR}/${BOX_FILENAME}"

# True if this exact name+provider+version is installed. Machine-readable
# because `vagrant box list` pads the name column to its longest entry, so a
# fixed-string match on "<name> (<provider>," stops working as boxes pile up.
box_installed() {
    vagrant box list --machine-readable 2>/dev/null \
        | awk -F, -v n="${VAGRANT_BOX_LOCAL_NAME}" -v p="${PROVIDER}" -v v="${BOX_VERSION}" '
            $3=="box-name"     {name=$4}
            $3=="box-provider" {prov=$4}
            $3=="box-version" && name==n && prov==p && $4==v {found=1}
            END {exit !found}'
}

# Skip download if the same version is already installed locally
if [ -f "${VERSION_MARKER}" ] && [ "$(cat "${VERSION_MARKER}")" = "${BOX_VERSION}" ]; then
    if box_installed; then
        echo "===> Box ${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER}) version ${BOX_VERSION} already present, skipping download"
        vagrant box list
        exit 0
    fi
fi

mkdir -p "${WORK_DIR}"

echo "===> Downloading ${BOX_FILENAME} (version ${BOX_VERSION})"
rclone copyto \
    "${BOX_PREFIX}/${BOX_FILENAME}" \
    "${WORK_DIR}/${BOX_FILENAME}"

echo "===> Downloading checksum"
rclone copyto \
    "${BOX_PREFIX}/${BOX_FILENAME}.md5sums.txt" \
    "${WORK_DIR}/${BOX_FILENAME}.md5sums.txt"

echo "===> Verifying checksum"
(cd "${WORK_DIR}" && md5sum -c "${BOX_FILENAME}.md5sums.txt")

echo "===> Removing any existing local box for ${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER})"
vagrant box remove "${VAGRANT_BOX_LOCAL_NAME}" --provider "${PROVIDER}" --all --force || true

# `box remove` leaves the pool volume behind, so every prefetch of a new
# version orphans the last one until a disk emergency collects it.
prune_superseded_pool_volumes() {
    local escaped="${VAGRANT_BOX_LOCAL_NAME//\//-VAGRANTSLASH-}"
    local ver_re pool vol
    if virsh -c qemu:///system list --state-running --name 2>/dev/null | grep -q '^vagrant-'; then
        echo "     a vagrant domain is running, leaving the pool alone"
        return 0
    fi
    ver_re=$(printf '%s' "${BOX_VERSION}" | sed 's/[.[\*^$]/\\&/g')
    for pool in $(virsh -c qemu:///system pool-list 2>/dev/null | awk 'NR>2 && $1 {print $1}'); do
        for vol in $(virsh -c qemu:///system vol-list --pool "${pool}" 2>/dev/null \
                       | awk 'NR>2 && $1 {print $1}' \
                       | grep -F "${escaped}_vagrant_box_image_" \
                       | grep -vE "_vagrant_box_image_${ver_re}([_.]|$)" || true); do
            echo "     removing superseded pool volume ${vol}"
            virsh -c qemu:///system vol-delete --pool "${pool}" "${vol}" || true
        done
    done
}

echo "===> Removing superseded pool volumes for ${VAGRANT_BOX_LOCAL_NAME}"
prune_superseded_pool_volumes

# Synthesize metadata.json so vagrant registers the box at BOX_VERSION;
# adding the bare .box would register as v0 and trigger a re-fetch from box_url.
LOCAL_METADATA="${WORK_DIR}/${BOX_NAME}.local.metadata.json"
python3 - "${VAGRANT_BOX_LOCAL_NAME}" "${BOX_VERSION}" "${PROVIDER}" \
    "${WORK_DIR}/${BOX_FILENAME}" "${LOCAL_METADATA}" <<'PY'
import json, sys
name, version, provider, box_path, out_path = sys.argv[1:6]
json.dump({
    "name": name,
    "versions": [{
        "version": version,
        "providers": [{"name": provider, "url": f"file://{box_path}"}],
    }],
}, open(out_path, "w"))
PY

echo "===> Adding box as ${VAGRANT_BOX_LOCAL_NAME} (version ${BOX_VERSION})"
vagrant box add --force "${LOCAL_METADATA}"

echo "${BOX_VERSION}" > "${VERSION_MARKER}"

echo "===> Box registered successfully:"
vagrant box list
