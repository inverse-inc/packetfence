#!/bin/bash
# Stage 3 (container): assemble the final ISO inside debian:bookworm.
# Uses outputs of stage 1 (docker-images archive) and stage 2 (offline APT repo).
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
WORK_DIR="${WORK_DIR:-${SCRIPT_DIR}/work}"
REPO_DIR="${REPO_DIR:-${WORK_DIR}/repo}"
DOCKER_IMAGES_DIR="${DOCKER_IMAGES_DIR:-${WORK_DIR}/docker-images}"
ISOFILES_DIR="${ISOFILES_DIR:-${WORK_DIR}/isofiles}"

source "${SCRIPT_DIR}/../debian-version.conf"
ISO_IN="${ISO_IN:-${SCRIPT_DIR}/debian-${DEBIAN_VERSION}-amd64-DVD-1.iso}"
ISO_OUT="${ISO_OUT:-${SCRIPT_DIR}/packetfence-usb-installer.iso}"

export PF_VERSION="${PF_VERSION:-$(cut -d' ' -f2 < "${PF_ROOT}/conf/pf-release")}"
export PF_RELEASE="${PF_RELEASE:-$(< "${PF_ROOT}/conf/pf-release")}"
export PF_RELEASE_VERSION="${PF_RELEASE_VERSION:-$(sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g' <<< "${PF_RELEASE}")}"
BUILDER_IMAGE="${BUILDER_IMAGE:-debian:bookworm}"

# Sanity checks on inputs
[ -f "${ISO_IN}" ]                || { echo "ERROR: base ISO not found: ${ISO_IN}" >&2; exit 1; }
[ -d "${REPO_DIR}" ]              || { echo "ERROR: REPO_DIR not found (run stage 2 first): ${REPO_DIR}" >&2; exit 1; }
[ -d "${DOCKER_IMAGES_DIR}" ]     || { echo "ERROR: DOCKER_IMAGES_DIR not found (run stage 1 first): ${DOCKER_IMAGES_DIR}" >&2; exit 1; }

mkdir -p "${ISOFILES_DIR}"

echo "=============================================="
echo "Stage 3 (container ${BUILDER_IMAGE}): Assembling ISO"
echo "=============================================="

# Mount layout inside the container:
#   /pf-root             ro  — full project (so SCRIPT_DIR-derived paths resolve)
#   /work                rw  — work dir for ISOFILES_DIR
#   /work/repo           rw  — bound from host REPO_DIR (read by script)
#   /work/docker-images  rw  — bound from host DOCKER_IMAGES_DIR (read by script)
#   /iso-in              ro  — base DVD
#   /iso-out             rw  — directory holding the output ISO
ISO_IN_DIR=$(dirname "${ISO_IN}")
ISO_IN_NAME=$(basename "${ISO_IN}")
ISO_OUT_DIR=$(dirname "${ISO_OUT}")
ISO_OUT_NAME=$(basename "${ISO_OUT}")
mkdir -p "${ISO_OUT_DIR}"

docker run --rm \
    -v "${PF_ROOT}:/pf-root:ro" \
    -v "${ISOFILES_DIR}:/work/isofiles" \
    -v "${REPO_DIR}:/work/repo:ro" \
    -v "${DOCKER_IMAGES_DIR}:/work/docker-images:ro" \
    -v "${ISO_IN_DIR}:/iso-in:ro" \
    -v "${ISO_OUT_DIR}:/iso-out" \
    -e PF_VERSION \
    -e PF_RELEASE \
    -e PF_RELEASE_VERSION \
    -e ISO_IN="/iso-in/${ISO_IN_NAME}" \
    -e REPO_DIR=/work/repo \
    -e DOCKER_IMAGES_DIR=/work/docker-images \
    -e ISOFILES_DIR=/work/isofiles \
    -e ISO_OUT="/iso-out/${ISO_OUT_NAME}" \
    -e SCRIPT_DIR=/pf-root/ci/dvd-usb-iso \
    -w /pf-root/ci/dvd-usb-iso \
    "${BUILDER_IMAGE}" \
    bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq --no-install-recommends \
            xorriso cpio gzip coreutils
        /pf-root/ci/dvd-usb-iso/assemble-iso.sh
    '

# Output ISO and any work dirs created by root inside container — fix ownership.
docker run --rm \
    -v "${ISO_OUT_DIR}:/iso-out" \
    -v "${ISOFILES_DIR}:/work/isofiles" \
    "${BUILDER_IMAGE}" \
    bash -c "chown -R $(id -u):$(id -g) /iso-out /work/isofiles 2>/dev/null || true"

echo "=============================================="
echo "Stage 3 complete: ${ISO_OUT}"
ls -lh "${ISO_OUT}" 2>/dev/null || echo "(ISO not found at ${ISO_OUT})"
echo "=============================================="
