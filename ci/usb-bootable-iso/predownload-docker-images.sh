#!/bin/bash
set -o nounset -o pipefail -o errexit

# Arguments
DOCKER_IMAGES_DIR=${1:-./docker-images}

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

# Source configuration
source <(grep 'KNK_REGISTRY_URL' ${PF_ROOT}/config.mk | tr -d ' ')
KNK_REGISTRY_URL=${KNK_REGISTRY_URL:-ghcr.io/inverse-inc/packetfence}

# Get tag from environment or use devel
TAG_OR_BRANCH_NAME=${TAG_OR_BRANCH_NAME:-devel}

echo "=============================================="
echo "Pre-downloading Docker Images"
echo "=============================================="
echo "DOCKER_IMAGES_DIR: ${DOCKER_IMAGES_DIR}"
echo "KNK_REGISTRY_URL: ${KNK_REGISTRY_URL}"
echo "TAG_OR_BRANCH_NAME: ${TAG_OR_BRANCH_NAME}"
echo "=============================================="

# Create output directory
mkdir -p ${DOCKER_IMAGES_DIR}

# List of Docker images to download
# Based on containers directory (excluding build-only images)
CONTAINERS_IMAGES="
    pfcron
    pfcmd
    httpd.aaa
    pfstats
    pfconfig
    haproxy-admin
    httpd.admin_dispatcher
    haproxy-portal
    ntlm-auth-api
    pfldapexplorer
    pfdns-connector
    radiusd-acct
    radiusd-eduroam
    radiusd-load-balancer
    radiusd-cli
    pfperl-api
    httpd.portal
    pfsso
    api-frontend
    httpd.dispatcher
    pfacct
    radiusd-auth
    httpd.webservices
    pfsetacls
    pfpki
    pfconnector
    proxysql
    pfqueue
"

# Additional images that might be needed
EXTRA_IMAGES="
    fingerbank-db
    netdata
    kafka
"

# Combine all images
ALL_IMAGES="${CONTAINERS_IMAGES} ${EXTRA_IMAGES}"

# Pull all images first, then save together to share layers
RETRY_LIMIT=3
FAILED_IMAGES=""
PULLED_IMAGES=""
SUCCESS_COUNT=0
TOTAL_COUNT=0
OUTPUT_FILE="${DOCKER_IMAGES_DIR}/all-images.tar.gz"

# Check if already downloaded
if [ -f "${OUTPUT_FILE}" ]; then
    echo "Docker images archive already exists: ${OUTPUT_FILE}"
    echo "Size: $(du -h ${OUTPUT_FILE} | cut -f1)"
    echo "Delete it to re-download"
else
    # Pull all images
    for img in ${ALL_IMAGES}; do
        img=$(echo $img | tr -d ' ')
        [ -z "$img" ] && continue

        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        FULL_IMAGE="${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME}"

        echo "===> [$TOTAL_COUNT] Pulling: ${img}"

        # Pull image with retries
        PULLED=false
        for attempt in $(seq 1 $RETRY_LIMIT); do
            echo "    Attempt ${attempt}/${RETRY_LIMIT}..."
            if docker pull -q ${FULL_IMAGE} 2>/dev/null; then
                PULLED=true
                break
            else
                if [ $attempt -lt $RETRY_LIMIT ]; then
                    echo "    Retrying in 3 seconds..."
                    sleep 3
                fi
            fi
        done

        if [ "$PULLED" = false ]; then
            echo "    FAILED to pull: ${FULL_IMAGE}"
            FAILED_IMAGES="${FAILED_IMAGES} ${img}"
        else
            echo "    Pulled successfully"
            PULLED_IMAGES="${PULLED_IMAGES} ${FULL_IMAGE}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    done

    # Save ALL images in a single archive (shared layers are deduplicated)
    if [ -n "${PULLED_IMAGES}" ]; then
        echo ""
        echo "===> Saving all images to single archive (layers will be deduplicated)..."
        docker save ${PULLED_IMAGES} | gzip > ${OUTPUT_FILE}
        echo "Saved: $(du -h ${OUTPUT_FILE} | cut -f1)"
    fi
fi

# Create a loader script to import images on target system
cat > ${DOCKER_IMAGES_DIR}/load-images.sh << 'LOADER_EOF'
#!/bin/bash
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "Loading pre-downloaded Docker images..."

if [ -f "${SCRIPT_DIR}/all-images.tar.gz" ]; then
    echo "Loading all images from single archive..."
    gunzip -c "${SCRIPT_DIR}/all-images.tar.gz" | docker load
else
    # Fallback: load individual image files
    for img_file in ${SCRIPT_DIR}/*.tar.gz; do
        [ -f "$img_file" ] || continue
        img_name=$(basename "$img_file" .tar.gz)
        echo "Loading: ${img_name}"
        gunzip -c "$img_file" | docker load
    done
fi

echo "All Docker images loaded successfully!"
LOADER_EOF
chmod +x ${DOCKER_IMAGES_DIR}/load-images.sh

# Summary
TOTAL_SIZE=$(du -sh ${DOCKER_IMAGES_DIR} | cut -f1)

echo "=============================================="
echo "Docker Images Download Complete"
echo "=============================================="
echo "Successful: ${SUCCESS_COUNT}/${TOTAL_COUNT}"
echo "Total Size: ${TOTAL_SIZE}"
echo "Location: ${DOCKER_IMAGES_DIR}"
if [ -n "${FAILED_IMAGES}" ]; then
    echo "FAILED:${FAILED_IMAGES}"
    echo "=============================================="
    exit 1
fi
echo "=============================================="
