#!/bin/bash
set -o nounset -o pipefail -o errexit

# Upload a pipeline-baked vagrant .box to Linode under
# packetfence-vagrant-box/ci/<category>/<BOX_NAME>_<CI_PIPELINE_ID>.box.
# Private (box embeds CI secrets); test runners pull it with rclone creds.
#
# Required env vars:
#   BOX_NAME                  e.g. pfdeb12dev
#   CI_PIPELINE_ID
#   RESULT_DIR                directory where the .box was packaged
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#   RCLONE_LINODE_URL         e.g. https://us-east-1.linodeobjects.com
#
# Optional env vars:
#   PROVIDER      (default: libvirt)
#   BUCKET        (default: packetfence-vagrant-box)

PROVIDER=${PROVIDER:-libvirt}
BUCKET=${BUCKET:-packetfence-vagrant-box}

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
# shellcheck source=ci/lib/vagrant/box-category.sh
source "${SCRIPT_DIR}/box-category.sh"
CATEGORY=$(vagrant_box_category)

BOX_FILENAME="${BOX_NAME}-${PROVIDER}.box"
BOX_FILE="${RESULT_DIR}/${BOX_FILENAME}"
MD5_FILE="${BOX_FILE}.md5sums.txt"
REMOTE_KEY="${BOX_NAME}_${CI_PIPELINE_ID}.box"

# Env-config rclone remote: creds never appear on the command line.
export RCLONE_CONFIG_S3_TYPE=s3
export RCLONE_CONFIG_S3_PROVIDER=Ceph
export RCLONE_CONFIG_S3_ACCESS_KEY_ID=${RCLONE_ACCESS_KEY_ID}
export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=${RCLONE_SECRET_ACCESS_KEY}
export RCLONE_CONFIG_S3_ENDPOINT=${RCLONE_LINODE_URL}
export RCLONE_CONFIG_S3_ACL=private

if [ ! -f "${BOX_FILE}" ]; then
    echo "ERROR: box file not found: ${BOX_FILE}"
    exit 1
fi

echo "===> Computing checksum for ${BOX_FILENAME}"
BOX_CHECKSUM=$(md5sum "${BOX_FILE}" | cut -d' ' -f1)
echo "${BOX_CHECKSUM}  ${REMOTE_KEY}" > "${MD5_FILE}"

remote_prefix="s3:${BUCKET}/ci/${CATEGORY}"

echo "===> Uploading box to ${remote_prefix}/${REMOTE_KEY}"
rclone copyto "${BOX_FILE}" "${remote_prefix}/${REMOTE_KEY}"
rclone copyto "${MD5_FILE}" "${remote_prefix}/${REMOTE_KEY}.md5sums.txt"

echo "===> Done! Box available at:"
echo "     ${BUCKET}/ci/${CATEGORY}/${REMOTE_KEY}"
