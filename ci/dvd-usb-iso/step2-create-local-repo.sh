#!/bin/bash
# Stage 2 (container): build the offline APT repository inside debian:bookworm.
# This avoids the need for sudo or debootstrap/dpkg-dev on the host.
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
WORK_DIR="${WORK_DIR:-${SCRIPT_DIR}/work}"
REPO_DIR="${REPO_DIR:-${WORK_DIR}/repo}"

export PF_RELEASE_VERSION="${PF_RELEASE_VERSION:-15.1}"
export PF_REPO_TYPE="${PF_REPO_TYPE:-debian-branches}"
BUILDER_IMAGE="${BUILDER_IMAGE:-debian:bookworm}"

mkdir -p "${REPO_DIR}"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker command not found on host." >&2
    exit 1
fi

echo "=============================================="
echo "Stage 2 (container ${BUILDER_IMAGE}): Building offline APT repo"
echo "=============================================="
echo "PF_ROOT:             ${PF_ROOT}"
echo "REPO_DIR:            ${REPO_DIR}"
echo "PF_RELEASE_VERSION:  ${PF_RELEASE_VERSION}"
echo "PF_REPO_TYPE:        ${PF_REPO_TYPE}"
echo "=============================================="

# Run create-local-repo.sh as root inside the container.
# - PF_ROOT is mounted read-only at /pf-root so the script's path resolution
#   (SCRIPT_DIR=/pf-root/ci/dvd-usb-iso, PF_ROOT=/pf-root) works correctly.
# - REPO_DIR is mounted read-write at /repo for the output.
docker run --rm \
    -v "${PF_ROOT}:/pf-root:ro" \
    -v "${REPO_DIR}:/repo" \
    -e PF_REPO_TYPE \
    -e PF_RELEASE_VERSION \
    -w /pf-root/ci/dvd-usb-iso \
    "${BUILDER_IMAGE}" \
    bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq --no-install-recommends \
            debootstrap gnupg curl ca-certificates dpkg-dev
        /pf-root/ci/dvd-usb-iso/create-local-repo.sh /repo "'"${PF_RELEASE_VERSION}"'"
    '

# Files were written by root inside the container — fix ownership on host.
docker run --rm \
    -v "${REPO_DIR}:/repo" \
    "${BUILDER_IMAGE}" \
    chown -R "$(id -u):$(id -g)" /repo

echo "=============================================="
echo "Stage 2 complete: $(du -sh "${REPO_DIR}" | cut -f1) in ${REPO_DIR}"
echo "=============================================="
