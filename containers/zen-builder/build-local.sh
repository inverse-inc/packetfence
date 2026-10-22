#!/bin/bash
# Build the zen-builder image locally (IMAGE=<name>:<tag> to override).

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

: "${IMAGE:=zen-builder:local-test}"

echo "Building ${IMAGE}"

docker build \
    -t "${IMAGE}" \
    -f containers/zen-builder/Dockerfile \
    "${REPO_ROOT}"

echo "Done: ${IMAGE}"
