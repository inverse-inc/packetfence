#!/bin/bash
set -o nounset -o pipefail -o errexit

# Upload the PacketFence exportable backup produced by the configurator
# scenario to the Linode bucket.
#
# Flow (all host-side; the VM never touches S3 credentials):
#   1. Run addons/vagrant/playbooks/dump_pf_export.yml — runs
#      exportable-backup.sh inside the VM and fetches the .tgz to
#      ${RESULT_DIR}/pf-export.tgz on the runner.
#   2. Prune entries older than NB_DAYS_TO_KEEP in pf-export/ (host-side).
#   3. rclone copyto the local tarball to
#      :s3:${BUCKET}/pf-export/configurator_${CI_PIPELINE_ID}.tgz.
#
# Required env vars:
#   CI_PIPELINE_ID           GitLab pipeline id (used as the artifact key)
#   RCLONE_LINODE_URL
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#
# Optional env vars:
#   PF_EXPORT_ARCH           deb12 | el8 (default: last underscore-segment of
#                            CI_JOB_NAME, e.g. configurator_deb12 -> deb12).
#                            The deb12 and el8 PF configs differ (hostnames,
#                            IPs, package layout) so exports must not be
#                            cross-restored.
#   BUCKET                   (default: packetfence-vagrant-box)
#   EXPORT_PREFIX            (default: pf-export)
#   RESULT_DIR               (default: result)
#   VAGRANT_DIR              (default: ${CI_PROJECT_DIR}/addons/vagrant)
#   ANSIBLE_VM_LIST          host pattern (default: pf${PF_EXPORT_ARCH}dev)
#   LOCAL_TGZ                override local tarball path (default: ${RESULT_DIR}/pf-export.tgz)

BUCKET=${BUCKET:-packetfence-vagrant-box}
EXPORT_PREFIX=${EXPORT_PREFIX:-pf-export}
RESULT_DIR=${RESULT_DIR:-result}
VAGRANT_DIR=${VAGRANT_DIR:-${CI_PROJECT_DIR:-.}/addons/vagrant}
LOCAL_TGZ=${LOCAL_TGZ:-${RESULT_DIR}/pf-export.tgz}
# ${CI_JOB_NAME:-} so nounset doesn't fire before the guard below; empty
# job name -> empty arch -> caught by the PF_EXPORT_ARCH check.
_ci_job_name=${CI_JOB_NAME:-}
PF_EXPORT_ARCH=${PF_EXPORT_ARCH:-${_ci_job_name##*_}}

if [ -z "${CI_PIPELINE_ID:-}" ]; then
    echo "ERROR: CI_PIPELINE_ID must be set"
    exit 1
fi
if [ -z "${PF_EXPORT_ARCH}" ]; then
    echo "ERROR: PF_EXPORT_ARCH could not be derived from CI_JOB_NAME=${CI_JOB_NAME:-<unset>}"
    exit 1
fi

# Only the configurator VM is up (configurator_<arch> -> PF_VM_NAMES=pf<arch>dev);
# targeting the whole pfservers group would fail on stopped VMs and localhost.
ANSIBLE_VM_LIST=${ANSIBLE_VM_LIST:-pf${PF_EXPORT_ARCH}dev}

REMOTE_KEY="${EXPORT_PREFIX}/configurator_${PF_EXPORT_ARCH}_${CI_PIPELINE_ID}.tgz"

echo "===> upload-pf-export.sh inputs"
echo "     BUCKET            = ${BUCKET}"
echo "     PF_EXPORT_ARCH    = ${PF_EXPORT_ARCH}"
echo "     REMOTE_KEY        = ${REMOTE_KEY}"
echo "     LOCAL_TGZ         = ${LOCAL_TGZ}"
echo "     VAGRANT_DIR       = ${VAGRANT_DIR}"
echo "     ANSIBLE_VM_LIST   = ${ANSIBLE_VM_LIST}"

# 1. Dump + fetch via ansible (same pattern as get_logs.yml)
echo "===> Running dump_pf_export.yml"
mkdir -p "${RESULT_DIR}"
RESULT_DIR_ABS="$(cd "${RESULT_DIR}" && pwd)"
(
    cd "${VAGRANT_DIR}"
    RESULT_DIR="${RESULT_DIR_ABS}" \
        ansible-playbook playbooks/dump_pf_export.yml -l "${ANSIBLE_VM_LIST}"
)

if [ ! -f "${LOCAL_TGZ}" ]; then
    echo "ERROR: expected tarball ${LOCAL_TGZ} not found after dump_pf_export.yml"
    exit 1
fi

echo "===> Tarball ready: ${LOCAL_TGZ} ($(du -h "${LOCAL_TGZ}" | awk '{print $1}'))"

# 2. Prune old exports before uploading (mirrors the 3-day cleanup pattern
#    from commit 3d23ef44bd on feature/ci-bake-golden-vagrant-box).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUCKET="${BUCKET}" EXPORT_PREFIX="${EXPORT_PREFIX}" \
    "${SCRIPT_DIR}/cleanup-pf-exports.sh"

# 3. Upload via host-side rclone (credentials never leave the runner).
export RCLONE_S3_PROVIDER=Ceph
export RCLONE_S3_ACCESS_KEY_ID="${RCLONE_ACCESS_KEY_ID}"
export RCLONE_S3_SECRET_ACCESS_KEY="${RCLONE_SECRET_ACCESS_KEY}"
export RCLONE_S3_ENDPOINT="${RCLONE_LINODE_URL}"

echo "===> Uploading to :s3:${BUCKET}/${REMOTE_KEY}"
rclone copyto "${LOCAL_TGZ}" ":s3:${BUCKET}/${REMOTE_KEY}"

echo "===> Upload complete"
