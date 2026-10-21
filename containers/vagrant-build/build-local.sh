#!/bin/bash
# Build the vagrant-build image locally (IMAGE=<name>:<tag> to override).

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

: "${IMAGE:=vagrant-build:local-test}"

echo "Building ${IMAGE}"

docker build \
    -t "${IMAGE}" \
    -f containers/vagrant-build/Dockerfile \
    "${REPO_ROOT}"

echo "Done: ${IMAGE}"
