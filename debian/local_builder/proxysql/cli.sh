#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
UPSTREAM_REPO="https://github.com/sysown/proxysql.git"

usage() {
    echo "Usage: $0 [-f|--force] <PROXYSQL_VERSION> [PROXYSQL_TAG]"
    echo ""
    echo "Arguments:"
    echo "  -f, --force       Force rebuild (no cache)"
    echo "  PROXYSQL_VERSION  Version number for the package (e.g., 3.0.5)"
    echo "  PROXYSQL_TAG      Git tag to build from (default: v<PROXYSQL_VERSION>)"
    echo ""
    echo "Example:"
    echo "  $0 3.0.5              # Uses tag v3.0.5"
    echo "  $0 3.0.5 v3.0.5       # Explicit tag"
    echo "  $0 -f 3.0.5           # Force rebuild"
    exit 1
}

# Parse options
FORCE_BUILD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_BUILD="--no-cache"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Check arguments
if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
fi

PROXYSQL_VERSION="$1"
PROXYSQL_TAG="${2:-v${PROXYSQL_VERSION}}"

# Check if Dockerfile exists
DOCKERFILE="${SCRIPT_DIR}/Dockerfile"
if [[ ! -f "${DOCKERFILE}" ]]; then
    echo "Error: Dockerfile not found: ${DOCKERFILE}"
    exit 1
fi

# Check if patch file exists (version-specific)
MAJOR_MINOR="${PROXYSQL_VERSION%.*}"
PATCH_FILE="${SCRIPT_DIR}/0001-sd_notify-patch-${MAJOR_MINOR}.patch"
if [[ ! -f "${PATCH_FILE}" ]]; then
    # Try exact version
    PATCH_FILE="${SCRIPT_DIR}/0001-sd_notify-patch-${PROXYSQL_VERSION}.patch"
    if [[ ! -f "${PATCH_FILE}" ]]; then
        echo "Error: No patch file found for version ${PROXYSQL_VERSION}"
        echo "Expected: 0001-sd_notify-patch-${MAJOR_MINOR}.patch or 0001-sd_notify-patch-${PROXYSQL_VERSION}.patch"
        echo "Available patches:"
        ls -1 "${SCRIPT_DIR}"/0001-sd_notify-patch-*.patch 2>/dev/null || echo "  (none)"
        exit 1
    fi
fi
echo "Using patch: $(basename ${PATCH_FILE})"

# Check if tag exists in the upstream repo
echo "Checking if tag '${PROXYSQL_TAG}' exists in upstream..."
if ! git ls-remote --exit-code --tags "${UPSTREAM_REPO}" "${PROXYSQL_TAG}" > /dev/null 2>&1; then
    echo "Error: Tag '${PROXYSQL_TAG}' does not exist in ${UPSTREAM_REPO}"
    echo ""
    echo "Available v${PROXYSQL_VERSION%%.*}.x tags:"
    git ls-remote --tags "${UPSTREAM_REPO}" | grep "refs/tags/v${PROXYSQL_VERSION%%.*}\." | sed 's/.*refs\/tags\//  /' | grep -v '\^{}' | tail -10
    exit 1
fi
echo "Tag '${PROXYSQL_TAG}' found."

# Build the image
echo "Building Docker image with PROXYSQL_VERSION=${PROXYSQL_VERSION} PROXYSQL_TAG=${PROXYSQL_TAG}..."
docker build ${FORCE_BUILD} \
    --build-arg PROXYSQL_VERSION="${PROXYSQL_VERSION}" \
    --build-arg PROXYSQL_BRANCH="${PROXYSQL_TAG}" \
    -t local/proxysql \
    -f "${DOCKERFILE}" \
    "${SCRIPT_DIR}"

# Extract the deb file using docker cp (distroless images have no shell)
echo "Extracting .deb file..."
CONTAINER_ID=$(docker create local/proxysql)
docker cp "${CONTAINER_ID}:/tmp/." "${SCRIPT_DIR}/tmp_deb/"
docker rm "${CONTAINER_ID}" > /dev/null
mv "${SCRIPT_DIR}"/tmp_deb/*.deb "${SCRIPT_DIR}/"
rm -rf "${SCRIPT_DIR}/tmp_deb"

echo ""
echo "Done! Deb file extracted to: ${SCRIPT_DIR}/"
ls -la "${SCRIPT_DIR}"/*.deb

# Verify the build by installing in a clean Ubuntu container
TEST_IMAGE="ubuntu:24.04"
echo ""
echo "Verifying build in ${TEST_IMAGE}..."
DEB_FILE=$(ls "${SCRIPT_DIR}"/proxysql_${PROXYSQL_VERSION}*.deb 2>/dev/null | head -1)
if [[ -n "${DEB_FILE}" ]]; then
    echo "Testing: ${DEB_FILE}"
    docker run --rm -v "${DEB_FILE}:/tmp/proxysql.deb:ro" "${TEST_IMAGE}" bash -c '
        apt-get update -qq
        apt-get install -y -qq libssl3 libgnutls30 >/dev/null 2>&1
        dpkg-deb -x /tmp/proxysql.deb /
        echo "ProxySQL version:"
        /usr/bin/proxysql --version
    '
else
    echo "ERROR: No deb file found for version ${PROXYSQL_VERSION}"
fi
