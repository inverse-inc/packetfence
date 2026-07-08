#!/bin/bash
#
# build-deploy-pfconnector-remote-combined.sh
#
# Dev helper: build the pfconnector-remote-combined docker image locally with a
# CUSTOM fingerbank-collector-remote .deb (instead of the one from the PacketFence
# apt repo), then ship it over SSH to a server that already runs
# pfconnector-remote-combined and restart the service there.
#
# This lets you iterate on the collector without triggering CI.
#
# What it does:
#   1. Reads the image tag from the target server's conf/build_id (so the image
#      lands under exactly the tag the systemd wrapper will run).
#   2. Pulls the base images (radiusd, pfbuild-debian-bookworm) from GHCR.
#   3. Builds containers/pfconnector-remote/Dockerfile -> a "-base" image.
#   4. Overlays your custom fingerbank-collector-remote .deb on top (dpkg -i,
#      with systemctl stubbed the same way the Dockerfile does it).
#   5. docker save | ssh | docker load onto the target.
#   6. Restarts packetfence-pfconnector-remote-combined on the target.
#
# Usage:
#   tools/build-deploy-pfconnector-remote-combined.sh \
#       --deb /path/to/fingerbank-collector-remote_X.Y.Z_amd64.deb \
#       --target root@1.2.3.4 \
#       [--tag cloudDevel] \
#       [--registry ghcr.io/inverse-inc/packetfence] \
#       [--no-pull] [--no-restart] [--keep-base]
#
# Notes:
#   * Run from anywhere; the script cd's to the repo root for the build context.
#   * You must be logged in to GHCR (docker login ghcr.io) unless --no-pull and
#     the base images already exist locally.
#   * SSH must reach --target non-interactively (key auth) and docker must be
#     usable by that user on the target.

set -o nounset -o pipefail -o errexit

# ---- repo root (this script lives in tools/) --------------------------------
SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
PF_SRC_DIR=${SCRIPT_DIR%/*}

# ---- defaults ---------------------------------------------------------------
REGISTRY="ghcr.io/inverse-inc/packetfence"
LOCAL_REGISTRY="packetfence"
IMAGE_NAME="pfconnector-remote-combined"
DEB=""
TARGET=""
TAG=""
DO_PULL="yes"
DO_RESTART="yes"
KEEP_BASE="no"
REMOTE_BUILD_ID="/usr/local/pfconnector-remote/conf/build_id"
SERVICE="packetfence-pfconnector-remote-combined"

usage() {
    grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

# ---- args -------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --deb)        DEB="$2"; shift 2 ;;
        --target)     TARGET="$2"; shift 2 ;;
        --tag)        TAG="$2"; shift 2 ;;
        --registry)   REGISTRY="$2"; shift 2 ;;
        --no-pull)    DO_PULL="no"; shift ;;
        --no-restart) DO_RESTART="no"; shift ;;
        --keep-base)  KEEP_BASE="yes"; shift ;;
        -h|--help)    usage 0 ;;
        *) echo "Unknown argument: $1" >&2; usage 1 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "$(date '+%H:%M:%S') - $*"; }

[ -n "$DEB" ]    || die "--deb <path to fingerbank-collector-remote .deb> is required"
[ -n "$TARGET" ] || die "--target <user@host> is required"
[ -f "$DEB" ]    || die "deb file not found: $DEB"
[ -f "${PF_SRC_DIR}/containers/pfconnector-remote/Dockerfile" ] \
    || die "cannot find containers/pfconnector-remote/Dockerfile under ${PF_SRC_DIR}"

DEB_ABS=$(readlink -e "$DEB")

# ---- determine tag from the server, unless overridden -----------------------
if [ -z "$TAG" ]; then
    log "Reading image tag from ${TARGET}:${REMOTE_BUILD_ID}"
    TAG=$(ssh "$TARGET" "source ${REMOTE_BUILD_ID} 2>/dev/null; echo \$TAG_OR_BRANCH_NAME") \
        || die "could not read ${REMOTE_BUILD_ID} on ${TARGET}"
    TAG=$(echo "$TAG" | tr -d '[:space:]')
    [ -n "$TAG" ] || die "TAG_OR_BRANCH_NAME empty on ${TARGET}; pass --tag explicitly"
fi
log "Using tag: ${TAG}"

BASE_TAG="${LOCAL_REGISTRY}/${IMAGE_NAME}:${TAG}-base"
FINAL_TAG="${LOCAL_REGISTRY}/${IMAGE_NAME}:${TAG}"

# ---- pull base images from GHCR --------------------------------------------
if [ "$DO_PULL" = "yes" ]; then
    for base in radiusd pfbuild-debian-bookworm; do
        log "Pulling ${REGISTRY}/${base}:${TAG}"
        docker pull "${REGISTRY}/${base}:${TAG}" \
            || die "failed to pull ${REGISTRY}/${base}:${TAG} (docker login ghcr.io ?)"
    done
fi

# ---- stage A: build the stock pfconnector-remote image ----------------------
log "Building base image ${BASE_TAG}"
cd "$PF_SRC_DIR"
docker build \
    --build-arg "KNK_REGISTRY_URL=${REGISTRY}" \
    --build-arg "IMAGE_TAG=${TAG}" \
    -f containers/pfconnector-remote/Dockerfile \
    -t "${BASE_TAG}" \
    .

# ---- stage B: overlay the custom fingerbank-collector-remote .deb -----------
# We dpkg -i on top of the built image. The collector's postinst runs
# dh_systemd_enable / systemctl, which fails without a running systemd, so we
# stub systemctl the same way containers/pfconnector-remote/Dockerfile does.
OVERLAY_CTX=$(mktemp -d)
trap 'rm -rf "$OVERLAY_CTX"' EXIT
cp "$DEB_ABS" "${OVERLAY_CTX}/custom-fingerbank-collector-remote.deb"

cat > "${OVERLAY_CTX}/Dockerfile" <<'EOF'
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY custom-fingerbank-collector-remote.deb /tmp/custom-fingerbank-collector-remote.deb
RUN if [ -f /usr/bin/systemctl ]; then mv /usr/bin/systemctl /usr/bin/systemctl.real; fi && \
    ln -sf /bin/true /usr/bin/systemctl && \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && \
    chmod +x /usr/sbin/policy-rc.d && \
    dpkg -i /tmp/custom-fingerbank-collector-remote.deb && \
    rm -f /tmp/custom-fingerbank-collector-remote.deb /usr/sbin/policy-rc.d /usr/bin/systemctl && \
    if [ -f /usr/bin/systemctl.real ]; then mv /usr/bin/systemctl.real /usr/bin/systemctl; fi
EOF

log "Overlaying custom collector -> ${FINAL_TAG}"
docker build \
    --build-arg "BASE_IMAGE=${BASE_TAG}" \
    -f "${OVERLAY_CTX}/Dockerfile" \
    -t "${FINAL_TAG}" \
    "${OVERLAY_CTX}"

if [ "$KEEP_BASE" != "yes" ]; then
    docker rmi "${BASE_TAG}" >/dev/null 2>&1 || true
fi

# ---- ship over SSH ----------------------------------------------------------
log "Shipping ${FINAL_TAG} to ${TARGET} (docker save | ssh | docker load)"
docker save "${FINAL_TAG}" | gzip | ssh "$TARGET" 'gunzip | docker load'

# ---- restart the service ----------------------------------------------------
if [ "$DO_RESTART" = "yes" ]; then
    log "Restarting ${SERVICE} on ${TARGET}"
    ssh "$TARGET" "systemctl restart ${SERVICE}"
    log "Done. Follow logs with:  ssh ${TARGET} 'docker logs -f ${IMAGE_NAME}'"
else
    log "Image loaded on ${TARGET}. Restart manually with:  ssh ${TARGET} 'systemctl restart ${SERVICE}'"
fi
