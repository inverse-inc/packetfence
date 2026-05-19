#!/bin/bash
set -o nounset -o pipefail -o errexit

# Upload a packer-built vagrant .box to Linode Object Storage (packetfence-iso bucket)
# and maintain a Vagrant-compatible metadata.json for native versioning support.
#
# Required env vars:
#   BOX_NAME                  e.g. pfdeb12dev
#   BOX_VERSION               e.g. 15.1.20260519123456
#   RESULT_DIR                directory where packer wrote the box
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#   RCLONE_LINODE_URL         e.g. https://us-east-1.linodeobjects.com
#
# Optional env vars:
#   PROVIDER      (default: libvirt)
#   BUCKET        (default: packetfence-iso)
#   BUCKET_PREFIX (default: vagrant)
#   BOX_DESC      (default: empty; shown as version description in metadata.json)
#
# Usage:
#   BOX_NAME=pfdeb12dev BOX_VERSION=15.1.20260519123456 RESULT_DIR=/var/local/gitlab-runner/vagrant_img \
#     RCLONE_ACCESS_KEY_ID=... RCLONE_SECRET_ACCESS_KEY=... RCLONE_LINODE_URL=... \
#     ./upload-to-linode.sh

PROVIDER=${PROVIDER:-libvirt}
BUCKET=${BUCKET:-packetfence-iso}
BUCKET_PREFIX=${BUCKET_PREFIX:-vagrant}
BOX_DESC=${BOX_DESC:-}

BOX_FILENAME="${BOX_NAME}-${PROVIDER}.box"
BOX_FILE="${RESULT_DIR}/${BOX_NAME}/${BOX_FILENAME}"
MD5_FILE="${BOX_FILE}.md5sums.txt"

# Derive public HTTPS base URL from the S3 endpoint:
#   https://us-east-1.linodeobjects.com  ->  https://packetfence-iso.us-east-1.linodeobjects.com
PUBLIC_BASE_URL="${RCLONE_LINODE_URL/https:\/\//https://${BUCKET}.}"

RCLONE_OPTS="--s3-provider=Ceph \
  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID} \
  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY} \
  --s3-endpoint=${RCLONE_LINODE_URL} \
  --s3-acl=public-read"

if [ ! -f "${BOX_FILE}" ]; then
    echo "ERROR: box file not found: ${BOX_FILE}"
    exit 1
fi

echo "===> Computing checksum for ${BOX_FILENAME}"
BOX_CHECKSUM=$(md5sum "${BOX_FILE}" | cut -d' ' -f1)
echo "${BOX_CHECKSUM}  ${BOX_FILENAME}" > "${MD5_FILE}"

versioned_prefix=":s3:${BUCKET}/${BUCKET_PREFIX}/${BOX_NAME}/${BOX_VERSION}"
latest_prefix=":s3:${BUCKET}/${BUCKET_PREFIX}/${BOX_NAME}/latest"

echo "===> Uploading versioned box to ${versioned_prefix}/"
# shellcheck disable=SC2086
rclone mkdir ${RCLONE_OPTS} "${versioned_prefix}/"
# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} "${BOX_FILE}" "${versioned_prefix}/${BOX_FILENAME}"
# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} "${MD5_FILE}" "${versioned_prefix}/${BOX_FILENAME}.md5sums.txt"

echo "===> Uploading latest box to ${latest_prefix}/"
# shellcheck disable=SC2086
rclone mkdir ${RCLONE_OPTS} "${latest_prefix}/"
# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} "${BOX_FILE}" "${latest_prefix}/${BOX_FILENAME}"
# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} "${MD5_FILE}" "${latest_prefix}/${BOX_FILENAME}.md5sums.txt"

echo "===> Updating latest.txt -> ${BOX_VERSION}"
LATEST_TXT=$(mktemp)
echo "${BOX_VERSION}" > "${LATEST_TXT}"
# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} "${LATEST_TXT}" ":s3:${BUCKET}/${BUCKET_PREFIX}/${BOX_NAME}/latest.txt"
rm -f "${LATEST_TXT}"

echo "===> Updating metadata.json"
METADATA_FILE=$(mktemp)
METADATA_REMOTE=":s3:${BUCKET}/${BUCKET_PREFIX}/${BOX_NAME}/metadata.json"
BOX_PUBLIC_URL="${PUBLIC_BASE_URL}/${BUCKET_PREFIX}/${BOX_NAME}/${BOX_VERSION}/${BOX_FILENAME}"

# Download existing metadata.json or start fresh
# shellcheck disable=SC2086
if ! rclone copyto ${RCLONE_OPTS} "${METADATA_REMOTE}" "${METADATA_FILE}" 2>/dev/null; then
    echo '{"name":"inverse-inc/'"${BOX_NAME}"'","versions":[]}' > "${METADATA_FILE}"
fi

python3 - "${METADATA_FILE}" "${BOX_VERSION}" "${PROVIDER}" "${BOX_PUBLIC_URL}" "${BOX_CHECKSUM}" "${BOX_DESC}" <<'PYEOF'
import json, sys

meta_file, version, provider, box_url, checksum, desc = sys.argv[1:]

with open(meta_file) as f:
    meta = json.load(f)

new_version = {
    "version": version,
    "status": "active",
    "description_markdown": desc,
    "providers": [{
        "name": provider,
        "url": box_url,
        "checksum_type": "md5",
        "checksum": checksum
    }]
}

# Replace any existing entry for this version then prepend (newest first)
meta["versions"] = [v for v in meta.get("versions", []) if v["version"] != version]
meta["versions"].insert(0, new_version)

with open(meta_file, "w") as f:
    json.dump(meta, f, indent=2)
PYEOF

# shellcheck disable=SC2086
rclone copyto ${RCLONE_OPTS} "${METADATA_FILE}" "${METADATA_REMOTE}"
rm -f "${METADATA_FILE}"

echo "===> Done! Box available at:"
echo "     ${BUCKET}/${BUCKET_PREFIX}/${BOX_NAME}/${BOX_VERSION}/${BOX_FILENAME}"
echo "     ${BUCKET}/${BUCKET_PREFIX}/${BOX_NAME}/latest/${BOX_FILENAME}"
echo "     ${PUBLIC_BASE_URL}/${BUCKET_PREFIX}/${BOX_NAME}/metadata.json"
