#!/bin/bash
set -o nounset -o pipefail -o errexit

# Fetch a base vagrant box from the private packetfence-vagrant-box bucket via
# authenticated rclone and register it locally as inverse-inc/<BOX_NAME> at
# BOX_VERSION. Called by t/venom/test-wrapper.sh:prefetch_private_box() before
# `vagrant up`, because the bucket is private and vagrant's HTTP fetch of the
# inventory box_url returns 403.
#
# This is distinct from setup-vagrant-box.sh, which handles the per-pipeline
# CI bake artifact at packetfence-vagrant-box/ci/<category>/<BOX>_<PIPELINE>.box.
#
# Required: BOX_NAME (e.g. pfdeb12branch),
#           RCLONE_{ACCESS_KEY_ID,SECRET_ACCESS_KEY,LINODE_URL}.
# Optional: BOX_VERSION (default: latest from metadata.json),
#           BUCKET (default: packetfence-vagrant-box),
#           PROVIDER (default: libvirt),
#           VAGRANT_BOX_LOCAL_NAME (default: inverse-inc/${BOX_NAME}),
#           WORK_DIR (default: /var/local/gitlab-runner/vagrant_img_cache).

BOX_NAME=${BOX_NAME:?BOX_NAME must be set}
RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:?RCLONE_ACCESS_KEY_ID must be set}
RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:?RCLONE_SECRET_ACCESS_KEY must be set}
RCLONE_LINODE_URL=${RCLONE_LINODE_URL:?RCLONE_LINODE_URL must be set}

BUCKET=${BUCKET:-packetfence-vagrant-box}
PROVIDER=${PROVIDER:-libvirt}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}}
WORK_DIR=${WORK_DIR:-/var/local/gitlab-runner/vagrant_img_cache}
BOX_VERSION=${BOX_VERSION:-}

# Env-config rclone remote: creds never appear on the command line.
export RCLONE_CONFIG_S3_TYPE=s3
export RCLONE_CONFIG_S3_PROVIDER=Ceph
export RCLONE_CONFIG_S3_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID}
export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY}
export RCLONE_CONFIG_S3_ENDPOINT=${RCLONE_LINODE_URL}

remote_prefix="s3:${BUCKET}/${BOX_NAME}"

if [ -z "${BOX_VERSION}" ]; then
    echo "===> Resolving latest version for ${BOX_NAME} via metadata.json"
    meta=$(mktemp)
    trap 'rm -f "${meta}"' EXIT
    rclone copyto "${remote_prefix}/metadata.json" "${meta}"
    BOX_VERSION=$(python3 -c \
        'import json,sys; print(json.load(sys.stdin)["versions"][0]["version"])' \
        < "${meta}")
fi
echo "===> ${VAGRANT_BOX_LOCAL_NAME} v${BOX_VERSION}"

if vagrant box list 2>/dev/null \
        | grep -qF "${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER}, ${BOX_VERSION})"; then
    echo "===> Already registered, skipping download"
    exit 0
fi

mkdir -p "${WORK_DIR}"
work=$(mktemp -d -p "${WORK_DIR}")
trap 'rm -rf "${work}"' EXIT

box_file="${BOX_VERSION}.box"
echo "===> Downloading ${remote_prefix}/${box_file}"
rclone copyto "${remote_prefix}/${box_file}" "${work}/${box_file}"
echo "===> Downloading checksum"
rclone copyto "${remote_prefix}/${box_file}.md5sums.txt" "${work}/${box_file}.md5sums.txt"
echo "===> Verifying checksum"
( cd "${work}" && md5sum -c "${box_file}.md5sums.txt" )

# `vagrant box add` of a raw .box always registers as v0, which would re-trigger
# a box_url fetch (403). Go through a synthesized metadata.json so the box
# registers at BOX_VERSION and vagrant matches the inventory pin.
cat > "${work}/local-metadata.json" <<EOF
{
  "name": "${VAGRANT_BOX_LOCAL_NAME}",
  "versions": [{
    "version": "${BOX_VERSION}",
    "providers": [{"name": "${PROVIDER}", "url": "file://${work}/${box_file}"}]
  }]
}
EOF

echo "===> Adding ${VAGRANT_BOX_LOCAL_NAME} v${BOX_VERSION}"
vagrant box add --force "${work}/local-metadata.json" 2>&1 \
    | tr '\r' '\n' | { grep -v 'Progress: ' || true; }

echo "===> Done:"
vagrant box list | grep -F "${VAGRANT_BOX_LOCAL_NAME}" || true
