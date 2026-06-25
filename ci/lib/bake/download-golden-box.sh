#!/bin/bash
# Download a golden Vagrant .box from Linode Object Storage onto the test
# runner before tests start. Skips download if the file already exists locally
# and passes checksum verification (parallel jobs on the same runner).

set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
PF_SRC_DIR=$(echo "${SCRIPT_DIR}" | grep -oP '.*?(?=\/ci\/)')

source "${PF_SRC_DIR}/ci/lib/common/functions.sh"

configure_and_check() {
    BAKE_ARCH=${BAKE_ARCH:?BAKE_ARCH must be set (e.g. el8, deb12)}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:?CI_PIPELINE_ID must be set}
    RCLONE_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID:?RCLONE_ACCESS_KEY_ID must be set}
    RCLONE_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY:?RCLONE_SECRET_ACCESS_KEY must be set}
    RCLONE_LINODE_URL=${RCLONE_LINODE_URL:?RCLONE_LINODE_URL must be set}

    BUCKET=${BUCKET:-packetfence-iso}
    GOLDEN_BOX_DIR=${GOLDEN_BOX_DIR:-/var/local/gitlab-runner/golden_images/${CI_PIPELINE_ID}}
    BOX_FILENAME="pf${BAKE_ARCH}golden.box"
    GOLDEN_BOX_FILE="${GOLDEN_BOX_DIR}/${BOX_FILENAME}"
    REMOTE_PREFIX=":s3:${BUCKET}/golden/${CI_PIPELINE_ID}"

    RCLONE_OPTS="--s3-provider=Ceph \
      --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
      --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
      --s3-endpoint=${RCLONE_LINODE_URL}"

    declare -p BAKE_ARCH CI_PIPELINE_ID BUCKET GOLDEN_BOX_DIR BOX_FILENAME REMOTE_PREFIX
}

download() {
    if [ -f "${GOLDEN_BOX_FILE}" ]; then
        log_section "Golden box already present at ${GOLDEN_BOX_FILE}, verifying checksum"
        rclone copyto ${RCLONE_OPTS} "${REMOTE_PREFIX}/${BOX_FILENAME}.md5sums.txt" "/tmp/${BOX_FILENAME}.md5sums.txt"
        if (cd "${GOLDEN_BOX_DIR}" && md5sum -c "/tmp/${BOX_FILENAME}.md5sums.txt" 2>/dev/null); then
            echo "Checksum OK, skipping download"
            return 0
        fi
        echo "Checksum mismatch, re-downloading"
    fi

    mkdir -p "${GOLDEN_BOX_DIR}"

    log_section "Download golden box from ${REMOTE_PREFIX}/${BOX_FILENAME}"
    rclone copyto ${RCLONE_OPTS} "${REMOTE_PREFIX}/${BOX_FILENAME}" "${GOLDEN_BOX_FILE}"
    rclone copyto ${RCLONE_OPTS} "${REMOTE_PREFIX}/${BOX_FILENAME}.md5sums.txt" "${GOLDEN_BOX_DIR}/${BOX_FILENAME}.md5sums.txt"

    log_section "Verify checksum"
    (cd "${GOLDEN_BOX_DIR}" && md5sum -c "${BOX_FILENAME}.md5sums.txt")

    log_section "Golden box ready at ${GOLDEN_BOX_FILE}"
}

configure_and_check
download
