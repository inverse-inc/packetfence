#!/bin/bash
# Build the pfbuild-debian-bookworm image locally for testing.
#
# Usage (from repo root):
#   bash containers/pfbuild-bookworm/build-local.sh
#
# Override build args via environment variables, e.g.:
#   GOVERSION=go1.25.10 PF_MINOR_RELEASE=15.2 bash containers/pfbuild-bookworm/build-local.sh

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Resolve defaults from config.mk / conf/pf-release (same logic as ci/packer/Makefile).
_config_mk="${REPO_ROOT}/config.mk"
_pf_release_file="$(readlink -e "${REPO_ROOT}/conf/pf-release")"

: "${GOVERSION:=$(grep -m1 '^GOVERSION' "${_config_mk}" | sed 's/.*=\s*//')}"
: "${PF_MINOR_RELEASE:=$(perl -ne 'print $1 if (m/.*?(\d+\.\d+)\./)' "${_pf_release_file}")}"

IMAGE="ghcr.io/inverse-inc/packetfence/pfbuild-debian-bookworm:local-test"

echo "Building ${IMAGE}"
echo "  GOVERSION=${GOVERSION}"
echo "  PF_MINOR_RELEASE=${PF_MINOR_RELEASE}"

docker build \
    --build-arg GOVERSION="${GOVERSION}" \
    --build-arg PF_MINOR_RELEASE="${PF_MINOR_RELEASE}" \
    -t "${IMAGE}" \
    -f containers/pfbuild-bookworm/Dockerfile \
    "${REPO_ROOT}"

echo "Done: ${IMAGE}"
