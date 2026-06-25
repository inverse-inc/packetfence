#!/bin/bash
set -o nounset -o pipefail -o errexit

# Download a prebuilt vagrant box from Linode Object Storage and register it
# locally via `vagrant box add`.
#
# The bucket is private; all reads go through authenticated rclone.
#
# Resolution order (first match wins):
#   1. BOX_VERSION env set           -> use it verbatim (explicit pin)
#   2. metadata.json at <BOX_NAME>/<CI_COMMIT_REF_SLUG>/
#                                    -> latest version in that branch scope
#   3. flat <BOX_NAME>/ layout       -> latest version uploaded by the older
#                                       flat-layout branches (no slug subfolder)
#   4. flat <pfdeb12dev>/ layout     -> latest version on devel (fallback + loud warning)
#
# Required env vars:
#   BOX_NAME                 e.g. pfdeb12branch
#   RCLONE_LINODE_URL        S3 endpoint, e.g. https://us-ord-1.linodeobjects.com
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#
# Optional env vars:
#   BOX_VERSION             pin to this exact version (skips all metadata resolution).
#   CI_COMMIT_REF_SLUG      branch slug; used for branch-scoped metadata lookup.
#   BUCKET                  (default: packetfence-vagrant-box)
#   PROVIDER                (default: libvirt)
#   VAGRANT_BOX_LOCAL_NAME  (default: inverse-inc/${BOX_NAME})
#   WORK_DIR                (default: /var/local/gitlab-runner/vagrant_img_cache)
#
# Artifacts produced:
#   ${WORK_DIR}/resolved-box.env   -- BOX_NAME, BOX_VERSION, BOX_SOURCE_PATH
#
# Usage:
#   BOX_NAME=pfdeb12branch CI_COMMIT_REF_SLUG=feature-foo \
#     RCLONE_LINODE_URL=https://us-ord-1.linodeobjects.com \
#     RCLONE_ACCESS_KEY_ID=... RCLONE_SECRET_ACCESS_KEY=... \
#     ./setup-vagrant-box.sh

BUCKET=${BUCKET:-packetfence-vagrant-box}
PROVIDER=${PROVIDER:-libvirt}
VAGRANT_BOX_LOCAL_NAME=${VAGRANT_BOX_LOCAL_NAME:-inverse-inc/${BOX_NAME}}
WORK_DIR=${WORK_DIR:-/var/local/gitlab-runner/vagrant_img_cache}
BOX_VERSION=${BOX_VERSION:-}
CI_COMMIT_REF_SLUG=${CI_COMMIT_REF_SLUG:-}

# Devel fallback box — always flat layout regardless of BOX_NAME
DEVEL_FALLBACK_BOX="pfdeb12dev"

VERSION_MARKER="${WORK_DIR}/${BOX_NAME}.version"

# Credentials via rclone's native env vars, not CLI flags: flags show up in
# the process table, visible to other users on shared shell runners.
export RCLONE_S3_PROVIDER=Ceph
export RCLONE_S3_ACCESS_KEY_ID="${RCLONE_ACCESS_KEY_ID}"
export RCLONE_S3_SECRET_ACCESS_KEY="${RCLONE_SECRET_ACCESS_KEY}"
export RCLONE_S3_ENDPOINT="${RCLONE_LINODE_URL}"

BOX_PREFIX=":s3:${BUCKET}/${BOX_NAME}"

echo "===> setup-vagrant-box.sh inputs"
echo "     BOX_NAME              = ${BOX_NAME}"
echo "     BOX_VERSION (pinned)  = ${BOX_VERSION:-<unset; will resolve via metadata.json>}"
echo "     CI_COMMIT_REF_SLUG    = ${CI_COMMIT_REF_SLUG:-<unset>}"
echo "     PROVIDER              = ${PROVIDER}"
echo "     VAGRANT_BOX_LOCAL_NAME= ${VAGRANT_BOX_LOCAL_NAME}"
echo "     RCLONE_LINODE_URL     = ${RCLONE_LINODE_URL:-<unset>}"
echo "     BOX_PREFIX            = ${BOX_PREFIX}"
echo "     WORK_DIR              = ${WORK_DIR}"

echo "===> Probing bucket layout for ${BOX_NAME}"
rclone lsf "${BOX_PREFIX}/" || echo "     (listing ${BOX_PREFIX}/ failed)"

# ---------------------------------------------------------------------------
# Resolution chain
# ---------------------------------------------------------------------------
BOX_SOURCE_PATH=""

if [ -n "${BOX_VERSION}" ]; then
    # Path 1: explicit pin
    echo "===> [path 1] Using pinned BOX_VERSION=${BOX_VERSION} (skipping metadata.json resolution)"
    if ! rclone lsf "${BOX_PREFIX}/${BOX_VERSION}.box" > /dev/null 2>&1; then
        echo "ERROR: pinned .box not found at ${BOX_PREFIX}/${BOX_VERSION}.box"
        exit 1
    fi
    BOX_SOURCE_PATH="${BOX_NAME}/${BOX_VERSION}.box"

elif [ -n "${CI_COMMIT_REF_SLUG}" ]; then
    # Path 2: branch-scoped metadata.json
    BRANCH_META_REMOTE=":s3:${BUCKET}/${BOX_NAME}/${CI_COMMIT_REF_SLUG}/metadata.json"
    META_BODY=$(mktemp)
    trap 'rm -f "${META_BODY}"' EXIT
    echo "===> [path 2] Trying branch-scoped metadata: ${BOX_NAME}/${CI_COMMIT_REF_SLUG}/metadata.json"
    if rclone copyto "${BRANCH_META_REMOTE}" "${META_BODY}" 2>/dev/null; then
        BOX_VERSION=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["versions"][0]["version"])' < "${META_BODY}")
        BOX_SOURCE_PATH="${BOX_NAME}/${CI_COMMIT_REF_SLUG}/${BOX_VERSION}.box"
        BOX_PREFIX=":s3:${BUCKET}/${BOX_NAME}/${CI_COMMIT_REF_SLUG}"
        echo "     Latest branch version: ${BOX_VERSION}"
    elif rclone copyto ":s3:${BUCKET}/${BOX_NAME}/metadata.json" "${META_BODY}" 2>/dev/null; then
        # Path 3: flat BOX_NAME layout — boxes uploaded by the older
        # flat-layout branches (e.g. fix/bring-vagrant-images-back-rebased).
        echo "===> [path 3] No branch-scoped box for ${CI_COMMIT_REF_SLUG}; using flat ${BOX_NAME}/metadata.json"
        BOX_VERSION=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["versions"][0]["version"])' < "${META_BODY}")
        BOX_SOURCE_PATH="${BOX_NAME}/${BOX_VERSION}.box"
        echo "     Flat layout version: ${BOX_VERSION}"
    else
        # Path 4: devel flat fallback
        echo ""
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "WARNING: no branch-scoped or flat box found for ${BOX_NAME}"
        echo "         Falling back to devel box (${DEVEL_FALLBACK_BOX}).  This means run B"
        echo "         is testing with the devel box, not the branch box produced by run A."
        echo "         Trigger BUILD_PF_IMG_VAGRANT=yes on this branch to build a branch box."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo ""
        DEVEL_META_REMOTE=":s3:${BUCKET}/${DEVEL_FALLBACK_BOX}/metadata.json"
        if ! rclone copyto "${DEVEL_META_REMOTE}" "${META_BODY}" 2>/dev/null; then
            echo "ERROR: failed to fetch devel fallback metadata: ${DEVEL_META_REMOTE}"
            exit 1
        fi
        BOX_VERSION=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["versions"][0]["version"])' < "${META_BODY}")
        BOX_SOURCE_PATH="${DEVEL_FALLBACK_BOX}/${BOX_VERSION}.box"
        BOX_PREFIX=":s3:${BUCKET}/${DEVEL_FALLBACK_BOX}"
        echo "     Devel fallback version: ${BOX_VERSION}"
    fi

else
    # Path 3 (no slug): flat metadata.json on BOX_NAME itself
    META_BODY=$(mktemp)
    trap 'rm -f "${META_BODY}"' EXIT
    METADATA_REMOTE="${BOX_PREFIX}/metadata.json"
    echo "===> [path 3] No CI_COMMIT_REF_SLUG; resolving latest from ${METADATA_REMOTE}"
    if ! rclone copyto "${METADATA_REMOTE}" "${META_BODY}"; then
        echo "ERROR: failed to fetch ${METADATA_REMOTE}"
        exit 1
    fi
    BOX_VERSION=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["versions"][0]["version"])' < "${META_BODY}")
    BOX_SOURCE_PATH="${BOX_NAME}/${BOX_VERSION}.box"
    echo "     Latest version: ${BOX_VERSION}"
fi

echo ""
echo "===> Resolved box:"
echo "     name    = ${VAGRANT_BOX_LOCAL_NAME}"
echo "     version = ${BOX_VERSION}"
echo "     source  = ${BOX_SOURCE_PATH}"
echo ""

# Write provenance artifact for the consuming job.
# Written to WORK_DIR (persistent on the runner) and optionally to
# CI_PROJECT_DIR so GitLab can capture it as a job artifact.
mkdir -p "${WORK_DIR}"
cat > "${WORK_DIR}/resolved-box.env" <<EOF
BOX_NAME=${BOX_NAME}
BOX_VERSION=${BOX_VERSION}
BOX_SOURCE_PATH=${BOX_SOURCE_PATH}
EOF
if [ -n "${CI_PROJECT_DIR:-}" ]; then
    cp "${WORK_DIR}/resolved-box.env" "${CI_PROJECT_DIR}/resolved-box.env"
fi

# Box file path under the resolved prefix
BOX_FILENAME="${BOX_VERSION}.box"

# Skip download if the same version is already installed locally
if [ -f "${VERSION_MARKER}" ] && [ "$(cat "${VERSION_MARKER}")" = "${BOX_VERSION}" ]; then
    if vagrant box list | grep -qF "${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER},"; then
        echo "===> Box ${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER}) version ${BOX_VERSION} already present, skipping download"
        vagrant box list
        exit 0
    fi
fi

echo "===> Downloading ${BOX_FILENAME} (version ${BOX_VERSION})"
rclone copyto \
    "${BOX_PREFIX}/${BOX_FILENAME}" \
    "${WORK_DIR}/${BOX_FILENAME}"

echo "===> Downloading checksum"
rclone copyto \
    "${BOX_PREFIX}/${BOX_FILENAME}.md5sums.txt" \
    "${WORK_DIR}/${BOX_FILENAME}.md5sums.txt"

echo "===> Verifying checksum"
(cd "${WORK_DIR}" && md5sum -c "${BOX_FILENAME}.md5sums.txt")

echo "===> Removing any existing local box for ${VAGRANT_BOX_LOCAL_NAME} (${PROVIDER})"
vagrant box remove "${VAGRANT_BOX_LOCAL_NAME}" --provider "${PROVIDER}" --all --force || true

# Synthesize metadata.json so vagrant registers the box at BOX_VERSION;
# adding the bare .box would register as v0 and trigger a re-fetch from box_url.
LOCAL_METADATA="${WORK_DIR}/${BOX_NAME}.local.metadata.json"
python3 - "${VAGRANT_BOX_LOCAL_NAME}" "${BOX_VERSION}" "${PROVIDER}" \
    "${WORK_DIR}/${BOX_FILENAME}" "${LOCAL_METADATA}" <<'PY'
import json, sys
name, version, provider, box_path, out_path = sys.argv[1:6]
json.dump({
    "name": name,
    "versions": [{
        "version": version,
        "providers": [{"name": provider, "url": f"file://{box_path}"}],
    }],
}, open(out_path, "w"))
PY

echo "===> Adding box as ${VAGRANT_BOX_LOCAL_NAME} (version ${BOX_VERSION})"
vagrant box add --force "${LOCAL_METADATA}"

echo "${BOX_VERSION}" > "${VERSION_MARKER}"

echo "===> Box registered successfully:"
vagrant box list
