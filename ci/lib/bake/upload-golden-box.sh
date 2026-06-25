#!/bin/bash
# Upload a golden Vagrant .box to Linode Object Storage so all test runners
# in the pipeline can download it. The box is stored under a pipeline-scoped
# path (golden/${CI_PIPELINE_ID}/) and purged at pipeline end.

set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
PF_SRC_DIR=$(echo "${SCRIPT_DIR}" | grep -oP '.*?(?=\/ci\/)')

source "${PF_SRC_DIR}/ci/lib/common/functions.sh"

configure_and_check() {
    GOLDEN_BOX_FILE=${GOLDEN_BOX_FILE:?GOLDEN_BOX_FILE must be set}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:?CI_PIPELINE_ID must be set}
    RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:?RCLONE_ACCESS_KEY_ID must be set}
    RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:?RCLONE_SECRET_ACCESS_KEY must be set}
    RCLONE_LINODE_URL=${RCLONE_LINODE_URL:?RCLONE_LINODE_URL must be set}

    BUCKET=${BUCKET:-packetfence-iso}
    BOX_FILENAME=$(basename "${GOLDEN_BOX_FILE}")
    REMOTE_PREFIX=":s3:${BUCKET}/golden/${CI_PIPELINE_ID}"

    RCLONE_OPTS="--s3-provider=Ceph \
      --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
      --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
      --s3-endpoint=${RCLONE_LINODE_URL} \
      --s3-acl=private"

    declare -p GOLDEN_BOX_FILE CI_PIPELINE_ID BUCKET BOX_FILENAME REMOTE_PREFIX
}

upload() {
    log_section "Compute checksum for ${BOX_FILENAME}"
    md5sum "${GOLDEN_BOX_FILE}" | cut -d' ' -f1 > "${GOLDEN_BOX_FILE}.md5"
    MD5=$(cat "${GOLDEN_BOX_FILE}.md5")
    echo "${MD5}  ${BOX_FILENAME}" > "${GOLDEN_BOX_FILE}.md5sums.txt"
    echo "MD5: ${MD5}"

    log_section "Upload golden box to ${REMOTE_PREFIX}/"
    rclone mkdir ${RCLONE_OPTS} "${REMOTE_PREFIX}/" || true
    rclone copyto ${RCLONE_OPTS} "${GOLDEN_BOX_FILE}" "${REMOTE_PREFIX}/${BOX_FILENAME}"
    rclone copyto ${RCLONE_OPTS} "${GOLDEN_BOX_FILE}.md5sums.txt" "${REMOTE_PREFIX}/${BOX_FILENAME}.md5sums.txt"

    log_section "Upload complete: ${REMOTE_PREFIX}/${BOX_FILENAME}"
}

configure_and_check
upload
