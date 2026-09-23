#!/bin/bash
set -o nounset -o pipefail -o errexit

# Fetch prebaked/<BOX_NAME>_<CI_PIPELINE_ID>.box from Linode and
# register as inverse-inc/<BOX_NAME>-<category> v0.0.<CI_PIPELINE_ID>.
#
# Required: BOX_NAME, CI_PIPELINE_ID, RCLONE_{ACCESS_KEY_ID,SECRET_ACCESS_KEY,LINODE_URL}

RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:?RCLONE_ACCESS_KEY_ID must be set}
RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:?RCLONE_SECRET_ACCESS_KEY must be set}
RCLONE_LINODE_URL=${RCLONE_LINODE_URL:?RCLONE_LINODE_URL must be set}

BUCKET=${BUCKET:-packetfence-vagrant-box}
PROVIDER=${PROVIDER:-libvirt}

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
# shellcheck source=ci/lib/vagrant/box-category.sh
source "${SCRIPT_DIR}/box-category.sh"
CATEGORY=$(vagrant_box_category)

# Env-config rclone remote: creds never appear on the command line.
export RCLONE_CONFIG_S3_TYPE=s3
export RCLONE_CONFIG_S3_PROVIDER=Ceph
export RCLONE_CONFIG_S3_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID}
export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY}
export RCLONE_CONFIG_S3_ENDPOINT=${RCLONE_LINODE_URL}
remote_prefix="s3:${BUCKET}/prebaked"

VAGRANT_BOX_VERSION=${VAGRANT_BOX_VERSION:-0.0.${CI_PIPELINE_ID}}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}-${CATEGORY}}
REMOTE_KEY="${BOX_NAME}_${CI_PIPELINE_ID}.box"

# Shared box caches may be used by other jobs, including stopped recovery VMs.
# This downloader only cleans its own temporary directory.
echo "===> Box ${VAGRANT_BOX_LOCAL_NAME} version ${VAGRANT_BOX_VERSION}"

# Skip download if this pipeline's version is already registered (parallel
# test jobs on the same runner share the Vagrant box store)
if vagrant box list | grep -qF "${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER}, ${VAGRANT_BOX_VERSION})"; then
    echo "===> Box already present, skipping download"
    vagrant box list
    exit 0
fi

# Download to $HOME's volume, not /tmp (too small for an 8GB box on some
# runners). Each invocation owns its scratch directory.
DL_ROOT="${HOME}/.vagrant-box-dl"
mkdir -p "${DL_ROOT}"
WORK_DIR=$(mktemp -d -p "${DL_ROOT}")
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "===> Downloading ${REMOTE_KEY} (pipeline ${CI_PIPELINE_ID})"
rclone copyto "${remote_prefix}/${REMOTE_KEY}" "${WORK_DIR}/${REMOTE_KEY}"

echo "===> Downloading checksum"
rclone copyto "${remote_prefix}/${REMOTE_KEY}.md5sums.txt" "${WORK_DIR}/${REMOTE_KEY}.md5sums.txt"

echo "===> Verifying checksum"
(cd "${WORK_DIR}" && md5sum -c "${REMOTE_KEY}.md5sums.txt")

# `vagrant box add` of a raw .box always registers as version 0 — go via
# a synthesized metadata.json so VAGRANT_BOX_VERSION sticks.
BOX_CHECKSUM=$(cut -d' ' -f1 "${WORK_DIR}/${REMOTE_KEY}.md5sums.txt")
cat > "${WORK_DIR}/metadata.json" <<EOF
{
  "name": "${VAGRANT_BOX_LOCAL_NAME}",
  "versions": [{
    "version": "${VAGRANT_BOX_VERSION}",
    "providers": [{
      "name": "${PROVIDER}",
      "url": "file://${WORK_DIR}/${REMOTE_KEY}",
      "checksum_type": "md5",
      "checksum": "${BOX_CHECKSUM}"
    }]
  }]
}
EOF

echo "===> Adding box as ${VAGRANT_BOX_LOCAL_NAME} version ${VAGRANT_BOX_VERSION}"
# Drop per-tick "Progress:" lines; pipefail keeps vagrant's exit code
vagrant box add \
    --provider "${PROVIDER}" \
    --force \
    "${WORK_DIR}/metadata.json" 2>&1 \
    | tr '\r' '\n' | { grep -v 'Progress: ' || true; }

echo "===> Box registered successfully:"
vagrant box list
