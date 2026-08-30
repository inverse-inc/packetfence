#!/bin/bash
set -o nounset -o pipefail -o errexit

# Upload a packer-built vagrant .box to Linode Object Storage (packetfence-vagrant-box bucket)
# and maintain a Vagrant-compatible metadata.json for native versioning support.
#
# Required env vars:
#   BOX_NAME                  e.g. pfdeb12dev
#   BOX_VERSION               e.g. 15.1.20260519123456
#   RESULT_DIR                directory where packer wrote the box
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#   RCLONE_LINODE_URL         e.g. https://us-ord-1.linodeobjects.com
#
# Optional env vars:
#   REF_SLUG      branch slug (CI_COMMIT_REF_SLUG); when set, boxes upload under
#                 <BOX_NAME>/<REF_SLUG>/ with their own metadata.json.
#                 Devel/maintenance/stable jobs leave REF_SLUG unset → flat layout.
#   PROVIDER      (default: libvirt)
#   BUCKET        (default: packetfence-vagrant-box)
#   BOX_DESC      (default: empty; shown as version description in metadata.json)
#
# Usage:
#   BOX_NAME=pfdeb12dev BOX_VERSION=15.1.20260519123456 RESULT_DIR=/var/local/gitlab-runner/vagrant_img \
#     RCLONE_ACCESS_KEY_ID=... RCLONE_SECRET_ACCESS_KEY=... RCLONE_LINODE_URL=... \
#     ./upload-to-linode.sh

PROVIDER=${PROVIDER:-libvirt}
BUCKET=${BUCKET:-packetfence-vagrant-box}
BOX_DESC=${BOX_DESC:-}
REF_SLUG=${REF_SLUG:-}

# Packer writes the artifact under the per-build output_dir; the upload-time
# rename flattens to <box>/<version>.box with no extra directory.
LOCAL_BOX_FILE="${RESULT_DIR}/${BOX_NAME}/${BOX_NAME}-${PROVIDER}.box"
REMOTE_BOX_FILENAME="${BOX_VERSION}.box"
MD5_FILE="${LOCAL_BOX_FILE}.md5sums.txt"

# Derive public HTTPS base URL from the S3 endpoint:
#   https://us-ord-1.linodeobjects.com  ->  https://packetfence-vagrant-box.us-ord-1.linodeobjects.com
PUBLIC_BASE_URL="${RCLONE_LINODE_URL/https:\/\//https://${BUCKET}.}"

# Credentials via rclone's native env vars, not CLI flags: flags show up in
# the process table, visible to other users on shared shell runners.
export RCLONE_S3_PROVIDER=Ceph
export RCLONE_S3_ACCESS_KEY_ID="${RCLONE_ACCESS_KEY_ID}"
export RCLONE_S3_SECRET_ACCESS_KEY="${RCLONE_SECRET_ACCESS_KEY}"
export RCLONE_S3_ENDPOINT="${RCLONE_LINODE_URL}"

if [ ! -f "${LOCAL_BOX_FILE}" ]; then
    echo "ERROR: box file not found: ${LOCAL_BOX_FILE}"
    exit 1
fi

echo "===> Computing checksum for ${REMOTE_BOX_FILENAME}"
BOX_CHECKSUM=$(md5sum "${LOCAL_BOX_FILE}" | cut -d' ' -f1)
echo "${BOX_CHECKSUM}  ${REMOTE_BOX_FILENAME}" > "${MD5_FILE}"

# Branch builds upload under <BOX_NAME>/<REF_SLUG>/; devel/stable use flat <BOX_NAME>/ layout.
if [ -n "${REF_SLUG}" ]; then
    box_prefix=":s3:${BUCKET}/${BOX_NAME}/${REF_SLUG}"
    BOX_PUBLIC_URL="${PUBLIC_BASE_URL}/${BOX_NAME}/${REF_SLUG}/${REMOTE_BOX_FILENAME}"
    echo "===> Branch-scoped upload: ${BOX_NAME}/${REF_SLUG}/"
else
    box_prefix=":s3:${BUCKET}/${BOX_NAME}"
    BOX_PUBLIC_URL="${PUBLIC_BASE_URL}/${BOX_NAME}/${REMOTE_BOX_FILENAME}"
fi

echo "===> Uploading ${REMOTE_BOX_FILENAME} to ${box_prefix}/"
rclone copyto "${LOCAL_BOX_FILE}" "${box_prefix}/${REMOTE_BOX_FILENAME}"
rclone copyto "${MD5_FILE}" "${box_prefix}/${REMOTE_BOX_FILENAME}.md5sums.txt"

echo "===> Updating metadata.json"
METADATA_FILE=$(mktemp)
METADATA_REMOTE="${box_prefix}/metadata.json"

# Download existing metadata.json or start fresh
if ! rclone copyto "${METADATA_REMOTE}" "${METADATA_FILE}" 2>/dev/null; then
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

rclone copyto "${METADATA_FILE}" "${METADATA_REMOTE}"
rm -f "${METADATA_FILE}"

echo "===> Done! Box available at:"
echo "     ${box_prefix#:s3:}/${REMOTE_BOX_FILENAME}"
echo "     ${PUBLIC_BASE_URL}/${BOX_NAME}${REF_SLUG:+/${REF_SLUG}}/metadata.json"
