#!/bin/bash
# Purge golden Vagrant boxes older than 3 days from Linode Object Storage
# before uploading new ones. Aligns with GitLab repo cleanup schedule and
# prevents accumulation from failed pipelines without manual intervention.

set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
PF_SRC_DIR=$(echo "${SCRIPT_DIR}" | grep -oP '.*?(?=\/ci\/)')

source "${PF_SRC_DIR}/ci/lib/common/functions.sh"

configure_and_check() {
    RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:?RCLONE_ACCESS_KEY_ID must be set}
    RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:?RCLONE_SECRET_ACCESS_KEY must be set}
    RCLONE_LINODE_URL=${RCLONE_LINODE_URL:?RCLONE_LINODE_URL must be set}

    BUCKET=${BUCKET:-packetfence-iso}
    MAX_AGE_DAYS=${MAX_AGE_DAYS:-3}
    REMOTE_BASE=":s3:${BUCKET}/golden"

    RCLONE_OPTS="--s3-provider=Ceph \
      --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
      --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
      --s3-endpoint=${RCLONE_LINODE_URL}"

    declare -p BUCKET MAX_AGE_DAYS REMOTE_BASE
}

cleanup_old() {
    log_section "Cleanup golden boxes older than ${MAX_AGE_DAYS} days from Linode"

    # List directories under golden/ to see what we're deleting
    echo "Listing golden/ directories before cleanup:"
    rclone lsd ${RCLONE_OPTS} "${REMOTE_BASE}/" 2>/dev/null || echo "No golden/ directories found or path does not exist"

    # Delete all files under golden/ older than MAX_AGE_DAYS
    echo "Deleting files older than ${MAX_AGE_DAYS} days from ${REMOTE_BASE}/"
    if rclone delete ${RCLONE_OPTS} --min-age "${MAX_AGE_DAYS}d" "${REMOTE_BASE}/" --verbose; then
        echo "Old files deleted successfully"
    else
        echo "WARNING: Delete operation failed or no old files found (non-fatal)"
    fi

    # Remove empty directories (rclone delete leaves empty dirs)
    echo "Removing empty pipeline directories:"
    rclone rmdirs ${RCLONE_OPTS} "${REMOTE_BASE}/" --leave-root || echo "No empty directories to remove"

    echo "Listing golden/ directories after cleanup:"
    rclone lsd ${RCLONE_OPTS} "${REMOTE_BASE}/" 2>/dev/null || echo "No golden/ directories remain"
}

configure_and_check
cleanup_old
