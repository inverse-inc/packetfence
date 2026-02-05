#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
UPSTREAM_REPO="https://github.com/sysown/proxysql.git"

PROXYSQL_VERSION=""
PROXYSQL_TAG=""

usage() {
    echo "Usage: $0 [OPTIONS] (--proxysql VERSION | --proxysql-tag TAG)"
    echo ""
    echo "Required (one of):"
    echo "  --proxysql VERSION   ProxySQL version to build (e.g., 3.0.5) -> uses tag v3.0.5"
    echo "  --proxysql-tag TAG   ProxySQL git tag to build (e.g., v3.0.5) -> uses version 3.0.5"
    echo ""
    echo "Options:"
    echo "  -f, --force          Force rebuild (no cache)"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --proxysql 3.0.5        # Build v3.0.5"
    echo "  $0 --proxysql-tag v3.0.5   # Same as above (using tag)"
    echo "  $0 --proxysql 2.6.3        # Build v2.6.3"
    echo "  $0 -f --proxysql 3.0.5     # Force rebuild (no cache)"
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
        --proxysql)
            PROXYSQL_VERSION="$2"
            shift 2
            ;;
        --proxysql-tag)
            PROXYSQL_TAG="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

# Check required arguments - need either version or tag
if [[ -z "${PROXYSQL_VERSION}" && -z "${PROXYSQL_TAG}" ]]; then
    echo "Error: --proxysql VERSION or --proxysql-tag TAG is required"
    echo ""
    usage
fi

if [[ -n "${PROXYSQL_VERSION}" && -n "${PROXYSQL_TAG}" ]]; then
    echo "Error: Use --proxysql VERSION or --proxysql-tag TAG, not both"
    echo ""
    usage
fi

# Derive the missing value
if [[ -n "${PROXYSQL_VERSION}" ]]; then
    PROXYSQL_TAG="v${PROXYSQL_VERSION}"
else
    # Extract version from tag (strip leading 'v' if present)
    PROXYSQL_VERSION="${PROXYSQL_TAG#v}"
fi

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

# Verify the build by installing in a test container
echo ""
echo "Verifying build..."
DEB_FILE=$(ls "${SCRIPT_DIR}"/proxysql_${PROXYSQL_VERSION}*.deb 2>/dev/null | head -1)
MAJOR_VERSION="${PROXYSQL_VERSION%%.*}"

if [[ -n "${DEB_FILE}" ]]; then
    DEB_FILENAME=$(basename "${DEB_FILE}")
    echo "Testing: ${DEB_FILENAME}"

    if [[ "$MAJOR_VERSION" -ge 3 ]]; then
        # v3+ needs OpenSSL 3.2+, use Dockerfile_test with multi-stage build
        echo "ProxySQL v3+ detected, building with OpenSSL 3.2+"
        docker build \
            --build-arg DEB_FILE="${DEB_FILENAME}" \
            --build-arg PROXYSQL_VERSION="${PROXYSQL_VERSION}" \
            -f "${SCRIPT_DIR}/Dockerfile_test" \
            -t proxysql-test \
            "${SCRIPT_DIR}"
        docker run --rm proxysql-test
    else
        # v2.x uses system OpenSSL, simple inline test
        echo "ProxySQL v2.x detected, using system OpenSSL"
        docker run --rm -v "${DEB_FILE}:/tmp/proxysql.deb:ro" debian:12 bash -c '
            apt-get update -qq
            apt-get install -y -qq libssl3 libgnutls30 >/dev/null 2>&1
            apt-get install -y -f /tmp/proxysql.deb
            /usr/bin/proxysql --version
        '
    fi
else
    echo "ERROR: No deb file found for version ${PROXYSQL_VERSION}"
fi
