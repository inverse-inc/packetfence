#!/bin/bash
# Purge the pipeline-scoped golden images from Linode Object Storage.
# Local cleanup is handled by each test job's after_script (rm -rf per-runner).
# This job runs once at pipeline end to delete the remote storage copy.

set -o nounset -o pipefail

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
PF_SRC_DIR=$(echo "${SCRIPT_DIR}" | grep -oP '.*?(?=\/ci\/)')

source "${PF_SRC_DIR}/ci/lib/common/functions.sh"

configure_and_check() {
    CI_PIPELINE_ID=${CI_PIPELINE_ID:?CI_PIPELINE_ID must be set}
    GOLDEN_BOX_DIR=${GOLDEN_BOX_DIR:-/var/local/gitlab-runner/golden_images/${CI_PIPELINE_ID}}

    # Remote cleanup requires rclone credentials (best-effort if missing)
    RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:-}
    RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:-}
    RCLONE_LINODE_URL=${RCLONE_LINODE_URL:-}
    BUCKET=${BUCKET:-packetfence-iso}

    declare -p CI_PIPELINE_ID GOLDEN_BOX_DIR BUCKET
}

cleanup() {
    # Local cleanup: best-effort removal on this runner only. Each test job
    # cleans up its own copy via after_script, but the bake job may have left
    # a copy on the bake runner, and this cleanup job's runner may be reused.
    log_section "Cleanup local golden image dir on this runner (best-effort)"
    if [ -d "${GOLDEN_BOX_DIR}" ]; then
        rm -rf "${GOLDEN_BOX_DIR}"
        echo "Removed local ${GOLDEN_BOX_DIR}"
    else
        echo "Nothing to remove locally: ${GOLDEN_BOX_DIR} does not exist"
    fi

    if [ -n "${RCLONE_ACCESS_KEY_ID}" ] && [ -n "${RCLONE_SECRET_ACCESS_KEY}" ] && [ -n "${RCLONE_LINODE_URL}" ]; then
        log_section "Cleanup remote golden images on Linode"
        REMOTE_PREFIX=":s3:${BUCKET}/golden/${CI_PIPELINE_ID}"
        RCLONE_OPTS="--s3-provider=Ceph \
          --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
          --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
          --s3-endpoint=${RCLONE_LINODE_URL}"

        echo "Purging remote ${REMOTE_PREFIX}/"
        if rclone purge ${RCLONE_OPTS} "${REMOTE_PREFIX}/"; then
            echo "Remote cleanup successful"
        else
            echo "Remote cleanup failed (non-fatal)"
        fi
    else
        echo "Skipping remote cleanup: rclone credentials not available"
    fi
}

configure_and_check
cleanup
