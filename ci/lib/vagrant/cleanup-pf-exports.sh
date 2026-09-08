#!/bin/bash
set -o nounset -o pipefail -o errexit

# Prune PF export tarballs older than NB_DAYS_TO_KEEP days from the
# `pf-export/` prefix in the Linode bucket. Runs host-side via rclone with
# the same env-var pattern as setup-vagrant-box.sh.
#
# Required env vars:
#   RCLONE_LINODE_URL
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#
# Optional env vars:
#   BUCKET                   (default: packetfence-vagrant-box)
#   EXPORT_PREFIX            (default: pf-export)
#   NB_DAYS_TO_KEEP          (default: 3)

BUCKET=${BUCKET:-packetfence-vagrant-box}
EXPORT_PREFIX=${EXPORT_PREFIX:-pf-export}
NB_DAYS_TO_KEEP=${NB_DAYS_TO_KEEP:-3}

export RCLONE_S3_PROVIDER=Ceph
export RCLONE_S3_ACCESS_KEY_ID="${RCLONE_ACCESS_KEY_ID}"
export RCLONE_S3_SECRET_ACCESS_KEY="${RCLONE_SECRET_ACCESS_KEY}"
export RCLONE_S3_ENDPOINT="${RCLONE_LINODE_URL}"

REMOTE=":s3:${BUCKET}/${EXPORT_PREFIX}"
MIN_AGE="${NB_DAYS_TO_KEEP}d"

echo "===> cleanup-pf-exports.sh: pruning entries older than ${MIN_AGE} under ${REMOTE}/"

# rclone delete with --min-age is the canonical "delete older than N days" form;
# matches the 3-day pattern from feature/ci-bake-golden-vagrant-box (commit 3d23ef44bd).
rclone delete --min-age "${MIN_AGE}" "${REMOTE}/" || {
    echo "WARNING: cleanup failed (non-fatal); continuing so the upload still runs"
}
