#!/bin/bash
set -o nounset -o pipefail -o errexit

# Fetch ci/<category>/<BOX_NAME>_<CI_PIPELINE_ID>.box from Linode and
# register as inverse-inc/<BOX_NAME>-<category> v0.0.<CI_PIPELINE_ID>.
# Also prunes -branches bakes older than 3d and stale pf*branch base boxes.
#
# Required: BOX_NAME, CI_PIPELINE_ID, RCLONE_{ACCESS_KEY_ID,SECRET_ACCESS_KEY,LINODE_URL}

RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:?RCLONE_ACCESS_KEY_ID must be set}
RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:?RCLONE_SECRET_ACCESS_KEY must be set}
RCLONE_LINODE_URL=${RCLONE_LINODE_URL:?RCLONE_LINODE_URL must be set}

BUCKET=${BUCKET:-packetfence-vagrant-box}
PROVIDER=${PROVIDER:-libvirt}
MAX_AGE_DAYS=${MAX_AGE_DAYS:-3}

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
remote_prefix="s3:${BUCKET}/ci/${CATEGORY}"

VAGRANT_BOX_VERSION=${VAGRANT_BOX_VERSION:-0.0.${CI_PIPELINE_ID}}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}-${CATEGORY}}
REMOTE_KEY="${BOX_NAME}_${CI_PIPELINE_ID}.box"

# vagrant-libvirt mangles "inverse-inc/foo" → "inverse-inc-VAGRANTSLASH-foo"
# for the storage-pool volume name; replicate that to clean it up.
drop_pool_image() {
    local name="$1" version="$2"
    virsh -c qemu:///system vol-delete --pool default \
        "${name//\//-VAGRANTSLASH-}_vagrant_box_image_${version}_box.img" 2>/dev/null \
        || true
}

# Keep only the highest version of each pf*branch base box.
prune_branch_base_boxes() {
    local base_box latest v
    for base_box in $(vagrant box list 2>/dev/null \
                          | awk '$1 ~ /^inverse-inc\/pf.*branch$/ { print $1 }' \
                          | sort -u); do
        latest=$(vagrant box list | awk -v name="${base_box}" \
            '$1 == name { gsub(/\)/,"",$3); print $3 }' | sort -V | tail -1)
        [ -z "${latest}" ] && continue
        for v in $(vagrant box list | awk -v name="${base_box}" \
            '$1 == name { gsub(/\)/,"",$3); print $3 }'); do
            [ "${v}" = "${latest}" ] && continue
            echo "===> Pruning stale ${base_box} version ${v} (keeping ${latest})"
            vagrant box remove "${base_box}" --provider "${PROVIDER}" \
                --box-version "${v}" --force || true
            drop_pool_image "${base_box}" "${v}"
        done
    done
}

# Drop other versions of THIS box unconditionally (a feature branch's
# back-to-back bakes outrun MAX_AGE_DAYS and fill the box store); for
# other -branches box names keep the MAX_AGE_DAYS TTL.
prune_old_pipeline_branches() {
    local box_name version box_img
    while read -r box_name version; do
        [ "${box_name}" = "${VAGRANT_BOX_LOCAL_NAME}" ] && \
            [ "${version}" = "${VAGRANT_BOX_VERSION}" ] && continue
        box_img="${HOME}/.vagrant.d/boxes/${box_name//\//-VAGRANTSLASH-}/${version}/${PROVIDER}/box.img"
        [ -f "${box_img}" ] || continue
        if [ "${box_name}" = "${VAGRANT_BOX_LOCAL_NAME}" ] \
           || [ -n "$(find "${box_img}" -mtime "+${MAX_AGE_DAYS}" -print 2>/dev/null)" ]; then
            echo "===> Removing ${box_name} version ${version}"
            vagrant box remove "${box_name}" --provider "${PROVIDER}" \
                --box-version "${version}" --force || true
            drop_pool_image "${box_name}" "${version}"
        fi
    done < <(vagrant box list | awk '$1 ~ /^inverse-inc\/.*-branches$/ {
                gsub(/\)/,"",$3); print $1, $3 }')
}

echo "===> Box ${VAGRANT_BOX_LOCAL_NAME} version ${VAGRANT_BOX_VERSION}"

prune_branch_base_boxes
prune_old_pipeline_branches

# Skip download if this pipeline's version is already registered (parallel
# test jobs on the same runner share the Vagrant box store)
if vagrant box list | grep -qF "${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER}, ${VAGRANT_BOX_VERSION})"; then
    echo "===> Box already present, skipping download"
    vagrant box list
    exit 0
fi

WORK_DIR=$(mktemp -d)
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
