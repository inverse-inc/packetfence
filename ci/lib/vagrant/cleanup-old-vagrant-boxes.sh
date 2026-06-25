#!/bin/bash
# Sweep ci/branches/ on Linode before each upload. ci/devel/ and
# ci/maintenance/ are kept indefinitely — we always want a working bake
# for those refs on hand.

set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
PF_SRC_DIR=$(echo "${SCRIPT_DIR}" | grep -oP '.*?(?=\/ci\/)')

source "${PF_SRC_DIR}/ci/lib/common/functions.sh"

configure_and_check() {
    RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:?RCLONE_ACCESS_KEY_ID must be set}
    RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:?RCLONE_SECRET_ACCESS_KEY must be set}
    RCLONE_LINODE_URL=${RCLONE_LINODE_URL:?RCLONE_LINODE_URL must be set}

    BUCKET=${BUCKET:-packetfence-vagrant-box}
    MAX_AGE_DAYS=${MAX_AGE_DAYS:-3}
    REMOTE_BRANCHES="s3:${BUCKET}/ci/branches"

    # Env-config rclone remote: creds never appear on the command line.
    export RCLONE_CONFIG_S3_TYPE=s3
    export RCLONE_CONFIG_S3_PROVIDER=Ceph
    export RCLONE_CONFIG_S3_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID}
    export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY}
    export RCLONE_CONFIG_S3_ENDPOINT=${RCLONE_LINODE_URL}

    declare -p BUCKET MAX_AGE_DAYS REMOTE_BRANCHES
}

cleanup_old() {
    log_section "Cleanup feature-branch CI bakes older than ${MAX_AGE_DAYS} days from Linode"

    echo "Listing ${BUCKET}/ci/branches/ before cleanup:"
    rclone ls "${REMOTE_BRANCHES}/" 2>/dev/null || echo "No ${BUCKET}/ci/branches/ contents found"

    echo "Deleting files older than ${MAX_AGE_DAYS} days from ${REMOTE_BRANCHES}/"
    if rclone delete --min-age ${MAX_AGE_DAYS}d "${REMOTE_BRANCHES}/" --verbose; then
        echo "Old files deleted successfully"
    else
        echo "WARNING: Delete operation failed or no old files found (non-fatal)"
    fi

    echo "Listing ${BUCKET}/ci/branches/ after cleanup:"
    rclone ls "${REMOTE_BRANCHES}/" 2>/dev/null || echo "No ${BUCKET}/ci/branches/ contents remain"
}

configure_and_check
cleanup_old
