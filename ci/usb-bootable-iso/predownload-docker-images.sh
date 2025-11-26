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

# Download and save each image
RETRY_LIMIT=3
FAILED_IMAGES=""
SUCCESS_COUNT=0
TOTAL_COUNT=0

for img in ${ALL_IMAGES}; do
    img=$(echo $img | tr -d ' ')
    [ -z "$img" ] && continue

    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    FULL_IMAGE="${KNK_REGISTRY_URL}/${img}:${TAG_OR_BRANCH_NAME}"
    OUTPUT_FILE="${DOCKER_IMAGES_DIR}/${img}.tar.gz"

    echo "===> [$TOTAL_COUNT] Processing: ${img}"

    # Skip if already downloaded
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "    Already exists: ${OUTPUT_FILE}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        continue
    fi

    # Pull image with retries
    PULLED=false
    for attempt in $(seq 1 $RETRY_LIMIT); do
        echo "    Pulling (attempt ${attempt}/${RETRY_LIMIT})..."
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
        continue
    fi

    # Save image to tar.gz
    echo "    Saving to: ${OUTPUT_FILE}"
    docker save ${FULL_IMAGE} | gzip > ${OUTPUT_FILE}

    if [ -f "${OUTPUT_FILE}" ]; then
        SIZE=$(du -h ${OUTPUT_FILE} | cut -f1)
        echo "    Saved: ${SIZE}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "    FAILED to save: ${img}"
        FAILED_IMAGES="${FAILED_IMAGES} ${img}"
    fi
done

# Create a loader script to import images on target system
cat > ${DOCKER_IMAGES_DIR}/load-images.sh << 'LOADER_EOF'
#!/bin/bash
set -o nounset -o pipefail -o errexit

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "Loading pre-downloaded Docker images..."

for img_file in ${SCRIPT_DIR}/*.tar.gz; do
    [ -f "$img_file" ] || continue
    img_name=$(basename "$img_file" .tar.gz)
    echo "Loading: ${img_name}"
    gunzip -c "$img_file" | docker load
done

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
