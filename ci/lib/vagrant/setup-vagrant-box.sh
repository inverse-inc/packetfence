#!/bin/bash
set -o nounset -o pipefail -o errexit

# Fetch prebaked/<BOX_NAME>_<CI_PIPELINE_ID>.box from Linode and
# register as inverse-inc/<BOX_NAME>-<category> v0.0.<CI_PIPELINE_ID>.
# Also prunes -branches bakes to their newest version, stale pf*branch base
# boxes, and orphaned pool volumes.
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
remote_prefix="s3:${BUCKET}/prebaked"

VAGRANT_BOX_VERSION=${VAGRANT_BOX_VERSION:-0.0.${CI_PIPELINE_ID}}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}-${CATEGORY}}
REMOTE_KEY="${BOX_NAME}_${CI_PIPELINE_ID}.box"

# Keep only the highest version of each pf*branch base box. Pruned boxes'
# pool volumes are reaped by sweep_orphan_pool_images, which alone has the
# in-use and cross-home guards.
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
        done
    done
}

# Keep only what a job can still consume: for THIS box just the current
# version, for other -branches names their newest version until MAX_AGE_DAYS.
prune_old_pipeline_branches() {
    local box_name version latest box_img
    for box_name in $(vagrant box list 2>/dev/null \
                          | awk '$1 ~ /^inverse-inc\/.*-branches$/ { print $1 }' | sort -u); do
        latest=$(vagrant box list | awk -v name="${box_name}" \
            '$1 == name { gsub(/\)/,"",$3); print $3 }' | sort -V | tail -1)
        for version in $(vagrant box list | awk -v name="${box_name}" \
            '$1 == name { gsub(/\)/,"",$3); print $3 }'); do
            if [ "${box_name}" = "${VAGRANT_BOX_LOCAL_NAME}" ]; then
                [ "${version}" = "${VAGRANT_BOX_VERSION}" ] && continue
            elif [ "${version}" = "${latest}" ]; then
                box_img="${HOME}/.vagrant.d/boxes/${box_name//\//-VAGRANTSLASH-}/${version}/${PROVIDER}/box.img"
                [ -f "${box_img}" ] || continue
                [ -n "$(find "${box_img}" -mtime "+${MAX_AGE_DAYS}" -print 2>/dev/null)" ] || continue
            fi
            echo "===> Removing ${box_name} version ${version}"
            vagrant box remove "${box_name}" --provider "${PROVIDER}" \
                --box-version "${version}" --force || true
        done
    done
}

# True if any live domain's XML references volume ${1} (its backing image).
pool_vol_in_use() {
    local vol="$1" dom
    for dom in $(virsh -c qemu:///system list --name 2>/dev/null); do
        [ -n "${dom}" ] || continue
        virsh -c qemu:///system dumpxml "${dom}" 2>/dev/null \
            | grep -qF "${vol}" && return 0
    done
    return 1
}

# Pool-volume prefix backing every box registered in ANY runner home. The
# libvirt 'default' pool is shared system-wide (see cleanup-runner-disk.sh),
# so scan $HOME plus each /var/local/*/ home — never reap a sibling's box.
# Box dirs are .vagrant.d/boxes/<mangled-name>/<version>/<provider>/.
registered_pool_vols() {
    local p version name
    for p in "${HOME}"/.vagrant.d/boxes/*/*/"${PROVIDER}" \
             "${VAR_LOCAL:-/var/local}"/*/.vagrant.d/boxes/*/*/"${PROVIDER}"; do
        [ -d "${p}" ] || continue
        version=$(basename "$(dirname "${p}")")
        name=$(basename "$(dirname "$(dirname "${p}")")")
        echo "${name}_vagrant_box_image_${version}"
    done
}

# Volume names carry a _box_<N> disk suffix on current vagrant-libvirt
# (none on older); compare on the common prefix.
vol_prefix() {
    sed -E 's/(_box_[0-9]+)?(\.img)?$//' <<< "$1"
}

# Test teardown's `vagrant box remove` leaves the pool volume behind, and once
# the record is gone prune_old_pipeline_branches can't match it. Reap any
# unregistered, unused box volume — dead weight from a finished pipeline.
sweep_orphan_pool_images() {
    local vol reg
    declare -A keep
    while read -r reg; do keep["${reg}"]=1; done < <(registered_pool_vols)

    for vol in $(virsh -c qemu:///system vol-list default 2>/dev/null \
                     | awk '/_vagrant_box_image_/{print $1}'); do
        [ -n "${keep[$(vol_prefix "${vol}")]:-}" ] && continue
        if pool_vol_in_use "${vol}"; then
            echo "===> Keeping in-use orphan pool volume ${vol}"
            continue
        fi
        echo "===> Reaping orphan pool volume ${vol}"
        virsh -c qemu:///system vol-delete --pool default "${vol}" || true
    done
}

# Scratch that killed jobs leave behind, own $HOME only (boxes and pool
# volumes go through the guarded pruners below). Age gates keep anything a
# just-started sibling job could still own.
sweep_local_scratch() {
    local d
    # vagrant box-add Tempfiles — a killed add leaves a multi-GB one
    find "${HOME}/.vagrant.d/tmp" -mindepth 1 -maxdepth 1 -mmin +30 \
        -exec rm -rf {} + 2>/dev/null || true
    # empty version dirs left by vagrant box remove
    find "${HOME}/.vagrant.d/boxes" -mindepth 2 -maxdepth 2 -type d -empty \
        -delete 2>/dev/null || true
    # prefetch-base-box.sh work dirs orphaned by a killed prefetch
    find "${HOME}/vagrant_img_cache" -mindepth 1 -maxdepth 1 -mmin +60 \
        -exec rm -rf {} + 2>/dev/null || true
    # box downloads in /tmp from pre-DL_ROOT revisions of this script
    for d in /tmp/tmp.*; do
        [ -d "${d}" ] && [ -O "${d}" ] || continue
        compgen -G "${d}/*.box" >/dev/null || continue
        [ -n "$(find "${d}" -maxdepth 0 -mmin +30 2>/dev/null)" ] || continue
        echo "===> Removing stale box download dir ${d}"
        rm -rf "${d}"
    done
}

echo "===> Box ${VAGRANT_BOX_LOCAL_NAME} version ${VAGRANT_BOX_VERSION}"

sweep_local_scratch
prune_branch_base_boxes
prune_old_pipeline_branches
sweep_orphan_pool_images

# Skip download if this pipeline's version is already registered (parallel
# test jobs on the same runner share the Vagrant box store)
if vagrant box list | grep -qF "${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER}, ${VAGRANT_BOX_VERSION})"; then
    echo "===> Box already present, skipping download"
    vagrant box list
    exit 0
fi

# Download to $HOME's volume, not /tmp (too small for an 8GB box on some
# runners); wipe the dir first so a killed job's leftover can't fill it.
DL_ROOT="${HOME}/.vagrant-box-dl"
rm -rf "${DL_ROOT}"
mkdir -p "${DL_ROOT}"
WORK_DIR=$(mktemp -d -p "${DL_ROOT}")
trap 'rm -rf "${DL_ROOT}"' EXIT

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
