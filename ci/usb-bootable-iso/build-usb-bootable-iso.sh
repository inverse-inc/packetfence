#!/bin/bash
# Top-level USB bootable ISO build orchestrator.
#
# Runs the build in stages, with the privileged + tooling-heavy parts
# isolated inside debian:bookworm containers so the host needs only:
#   - docker (engine + client)
#   - wget (for the base DVD download, on host)
#
# Stage 0 (host):       Download base Debian DVD ISO if not cached
# Stage 1 (host):       Pre-pull PacketFence Docker images (uses host's docker daemon)
# Stage 2 (container):  Build offline APT repository (debootstrap + apt download)
# Stage 3 (container):  Assemble the final hybrid ISO (xorriso)
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
source "${SCRIPT_DIR}/../debian-version.conf"

# Configuration
ISO_IN="${ISO_IN:-debian-${DEBIAN_VERSION}-amd64-DVD-1.iso}"
ISO_OUT="${ISO_OUT:-packetfence-usb-installer.iso}"
WORK_DIR="${SCRIPT_DIR}/work"
ISOFILES_DIR="${WORK_DIR}/isofiles"
REPO_DIR="${WORK_DIR}/repo"
DOCKER_IMAGES_DIR="${WORK_DIR}/docker-images"
BUILDER_IMAGE="${BUILDER_IMAGE:-debian:bookworm}"

# Version info
PF_VERSION="${PF_VERSION:-$(cut -d' ' -f2 < "${PF_ROOT}/conf/pf-release")}"
PF_RELEASE="${PF_RELEASE:-$(< "${PF_ROOT}/conf/pf-release")}"
PF_RELEASE_VERSION="${PF_RELEASE_VERSION:-$(sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g' <<< "${PF_RELEASE}")}"

# Docker image tag for PacketFence containers
if [ -z "${TAG_OR_BRANCH_NAME:-}" ]; then
    if [ -n "${CI_COMMIT_TAG:-}" ]; then
        export TAG_OR_BRANCH_NAME="${CI_COMMIT_TAG}"
    elif [ -n "${CI_COMMIT_REF_SLUG:-}" ]; then
        export TAG_OR_BRANCH_NAME="${CI_COMMIT_REF_SLUG}"
    elif [ -f "${PF_ROOT}/conf/build_id" ]; then
        # shellcheck disable=SC1091
        source "${PF_ROOT}/conf/build_id"
        export TAG_OR_BRANCH_NAME
    else
        export TAG_OR_BRANCH_NAME="devel"
    fi
fi

# Resolve absolute paths used as ISO_IN/ISO_OUT for stage 3
if [[ "${ISO_IN}" != /* ]]; then ISO_IN="${SCRIPT_DIR}/${ISO_IN}"; fi
if [[ "${ISO_OUT}" != /* ]]; then ISO_OUT="${SCRIPT_DIR}/${ISO_OUT}"; fi

# Export so step scripts inherit
export WORK_DIR ISOFILES_DIR REPO_DIR DOCKER_IMAGES_DIR
export PF_VERSION PF_RELEASE PF_RELEASE_VERSION TAG_OR_BRANCH_NAME
export ISO_IN ISO_OUT BUILDER_IMAGE

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker command not found. Install Docker Engine to use this build." >&2
    exit 1
fi

# Optional: clean work directory unless SKIP_CLEAN=1
if [ "${SKIP_CLEAN:-0}" != "1" ]; then
    echo "===> Cleaning work directory (set SKIP_CLEAN=1 to keep)"
    if [ -d "${WORK_DIR}" ]; then
        chmod -R +w "${WORK_DIR}" 2>/dev/null || true
        rm -rf "${WORK_DIR}"
    fi
else
    echo "===> Keeping existing work directory (SKIP_CLEAN=1)"
fi

mkdir -p "${WORK_DIR}" "${ISOFILES_DIR}" "${REPO_DIR}" "${DOCKER_IMAGES_DIR}"

echo "=============================================="
echo "USB Bootable ISO build"
echo "=============================================="
echo "PF_VERSION:           ${PF_VERSION}"
echo "PF_RELEASE:           ${PF_RELEASE}"
echo "PF_RELEASE_VERSION:   ${PF_RELEASE_VERSION}"
echo "TAG_OR_BRANCH_NAME:   ${TAG_OR_BRANCH_NAME}"
echo "BUILDER_IMAGE:        ${BUILDER_IMAGE}"
echo "ISO_IN:               ${ISO_IN}"
echo "ISO_OUT:              ${ISO_OUT}"
echo "WORK_DIR:             ${WORK_DIR}"
echo "=============================================="

# Stage 0: Base Debian DVD ISO (host, wget)
echo ""
echo "===> Stage 0: Base Debian DVD ISO"
if ! [ -f "${ISO_IN}" ]; then
    if ! command -v wget >/dev/null 2>&1; then
        echo "ERROR: wget not found on host (needed to fetch base DVD)." >&2
        exit 1
    fi
    BASE_NAME=$(basename "${ISO_IN}")
    echo "Downloading ${BASE_NAME}... (~3.8 GB, several minutes)"
    wget --progress=dot:giga \
        "https://cdimage.debian.org/cdimage/archive/${DEBIAN_VERSION}/amd64/iso-dvd/${BASE_NAME}" \
        -O "${ISO_IN}"
    echo "Base ISO: $(du -h "${ISO_IN}" | cut -f1)"
else
    echo "Base ISO already present: ${ISO_IN} ($(du -h "${ISO_IN}" | cut -f1))"
fi

# Stage 1: Pre-pull Docker images (host)
echo ""
"${SCRIPT_DIR}/step1-pull-docker-images.sh"

# Stage 2: Build offline APT repository (container)
echo ""
"${SCRIPT_DIR}/step2-create-local-repo.sh"

# Stage 3: Assemble final ISO (container)
echo ""
"${SCRIPT_DIR}/step3-assemble-iso.sh"

echo ""
echo "=============================================="
echo "Build complete!"
echo "Output: ${ISO_OUT}"
[ -f "${ISO_OUT}" ] && echo "Size:   $(du -h "${ISO_OUT}" | cut -f1)"
echo "=============================================="
