#!/bin/bash
# Stage 1 (host): pre-pull PacketFence Docker images using the host's Docker daemon
# and save them to a single archive that will be baked into the ISO.
#
# Runs on the host because it needs the host's Docker daemon to access the
# registry. Output is consumed later by the ISO assembly stage.
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="${WORK_DIR:-${SCRIPT_DIR}/work}"
DOCKER_IMAGES_DIR="${DOCKER_IMAGES_DIR:-${WORK_DIR}/docker-images}"

mkdir -p "${DOCKER_IMAGES_DIR}"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker command not found on host. Install Docker first." >&2
    exit 1
fi

echo "=============================================="
echo "Stage 1 (host): Pre-pulling Docker images"
echo "=============================================="

"${SCRIPT_DIR}/predownload-docker-images.sh" "${DOCKER_IMAGES_DIR}"
