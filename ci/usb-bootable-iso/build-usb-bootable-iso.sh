#!/bin/bash
set -o nounset -o pipefail -o errexit

# Get script directory and source shared config
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
source "${SCRIPT_DIR}/../debian-version.conf"

# Install required packages if not present
echo "===> Checking/installing required packages..."
# Note: docker.io not listed - CI runner has Docker from docker.com repo
REQUIRED_PKGS="debootstrap xorriso dpkg-dev cpio gnupg"
MISSING_PKGS=""
for pkg in ${REQUIRED_PKGS}; do
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
        MISSING_PKGS="${MISSING_PKGS} ${pkg}"
    fi
done
if [ -n "${MISSING_PKGS}" ]; then
    echo "Installing missing packages:${MISSING_PKGS}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq ${MISSING_PKGS}
fi
# Verify docker is available (from any source)
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker command not found. Please install Docker."
    exit 1
fi

# Configuration
ISO_IN=${ISO_IN:-debian-${DEBIAN_VERSION}-amd64-DVD-1.iso}
ISO_OUT=${ISO_OUT:-packetfence-usb-installer.iso}
WORK_DIR=${SCRIPT_DIR}/work
ISOFILES_DIR=${WORK_DIR}/isofiles
REPO_DIR=${WORK_DIR}/repo
DOCKER_IMAGES_DIR=${WORK_DIR}/docker-images

# Clean work directory to avoid stale package conflicts
# Set SKIP_CLEAN=1 to skip cleaning (for faster rebuilds when debugging)
# Make files writable first because extracted ISO files have read-only permissions
if [ "${SKIP_CLEAN:-0}" != "1" ]; then
    echo "===> Cleaning work directory to avoid stale package conflicts"
    if [ -d "${WORK_DIR}" ]; then
        chmod -R +w "${WORK_DIR}"
    fi
    rm -rf "${WORK_DIR}"
else
    echo "===> Skipping work directory cleanup (SKIP_CLEAN=1)"
fi

# Version info
PF_VERSION=${PF_VERSION:-$(cut -d' ' -f2 < "${PF_ROOT}/conf/pf-release")}
PF_RELEASE=${PF_RELEASE:-$(< "${PF_ROOT}/conf/pf-release")}
PF_RELEASE_VERSION=${PF_RELEASE_VERSION:-$(sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g' <<< "$PF_RELEASE")}

# Docker image tag - use CI environment or source from build_id if available
if [ -z "${TAG_OR_BRANCH_NAME:-}" ]; then
    if [ -n "${CI_COMMIT_TAG:-}" ]; then
        export TAG_OR_BRANCH_NAME="${CI_COMMIT_TAG}"
    elif [ -n "${CI_COMMIT_REF_SLUG:-}" ]; then
        export TAG_OR_BRANCH_NAME="${CI_COMMIT_REF_SLUG}"
    elif [ -f "${PF_ROOT}/conf/build_id" ]; then
        source "${PF_ROOT}/conf/build_id"
        export TAG_OR_BRANCH_NAME
    else
        export TAG_OR_BRANCH_NAME="devel"
    fi
fi

echo "=============================================="
echo "Building USB Bootable ISO"
echo "=============================================="
echo "PF_VERSION: ${PF_VERSION}"
echo "PF_RELEASE: ${PF_RELEASE}"
echo "PF_RELEASE_VERSION: ${PF_RELEASE_VERSION}"
echo "TAG_OR_BRANCH_NAME: ${TAG_OR_BRANCH_NAME}"
echo "ISO_OUT: ${ISO_OUT}"
echo "=============================================="

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f ${SCRIPT_DIR}/preseed.cfg
    # Keep work directory for debugging if build fails
}
trap cleanup EXIT

# Create work directories
mkdir -p ${WORK_DIR}
mkdir -p ${ISOFILES_DIR}
mkdir -p ${REPO_DIR}
mkdir -p ${DOCKER_IMAGES_DIR}

# Step 1: Download base Debian DVD ISO if not present
echo "===> Step 1: Checking base Debian DVD ISO"
if ! [ -f ${SCRIPT_DIR}/${ISO_IN} ]; then
    echo "Downloading ${ISO_IN}... (this will take several minutes - ~3.8 GB)"
    wget --progress=dot:giga https://cdimage.debian.org/cdimage/archive/${DEBIAN_VERSION}/amd64/iso-dvd/${ISO_IN} -O ${SCRIPT_DIR}/${ISO_IN}
    echo "Download complete: $(du -h ${SCRIPT_DIR}/${ISO_IN} | cut -f1)"
else
    echo "Base DVD ISO already present: ${ISO_IN} ($(du -h ${SCRIPT_DIR}/${ISO_IN} | cut -f1))"
fi

# Step 2: Create local APT repository with all packages
echo "===> Step 2: Creating local APT repository"
${SCRIPT_DIR}/create-local-repo.sh ${REPO_DIR} ${PF_RELEASE_VERSION}

# Step 3: Pre-download Docker images
echo "===> Step 3: Pre-downloading Docker images"
${SCRIPT_DIR}/predownload-docker-images.sh ${DOCKER_IMAGES_DIR}

# Step 4: Extract base ISO
echo "===> Step 4: Extracting base ISO"
rm -rf ${ISOFILES_DIR}/*
xorriso -osirrox on -indev ${SCRIPT_DIR}/${ISO_IN} -extract / ${ISOFILES_DIR}

# Step 5: Generate preseed configuration
echo "===> Step 5: Generating preseed configuration"
sed -e "s/%%PF_VERSION%%/${PF_RELEASE_VERSION}/g" \
    -e "s/%%PF_RELEASE%%/${PF_RELEASE}/g" \
    "${SCRIPT_DIR}/preseed-offline.cfg.tmpl" > "${SCRIPT_DIR}/preseed.cfg"

# Step 6: Inject preseed into initrd
echo "===> Step 6: Injecting preseed into initrd"
chmod +w -R "${ISOFILES_DIR}/install.amd/"
gunzip ${ISOFILES_DIR}/install.amd/initrd.gz
echo preseed.cfg | cpio -H newc -o -A -F ${ISOFILES_DIR}/install.amd/initrd
gzip ${ISOFILES_DIR}/install.amd/initrd
chmod -w -R ${ISOFILES_DIR}/install.amd/

# Step 7: Add local repository to ISO
echo "===> Step 7: Adding local repository to ISO"
mkdir -p ${ISOFILES_DIR}/pf-repo
cp -r ${REPO_DIR}/* ${ISOFILES_DIR}/pf-repo/

# Step 8: Add Docker images to ISO
echo "===> Step 8: Adding Docker images to ISO"
mkdir -p ${ISOFILES_DIR}/docker-images
cp -r ${DOCKER_IMAGES_DIR}/* ${ISOFILES_DIR}/docker-images/

# Step 9: Copy post-installation script
echo "===> Step 9: Adding post-installation script"
cp ${SCRIPT_DIR}/postinst-offline.sh ${ISOFILES_DIR}/

# Step 10: Update boot configurations
echo "===> Step 10: Updating boot configurations"
chmod a+w ${ISOFILES_DIR}/isolinux/gtk.cfg ${ISOFILES_DIR}/isolinux/drkgtk.cfg ${ISOFILES_DIR}/isolinux/menu.cfg ${ISOFILES_DIR}/boot/grub/grub.cfg || true
cp ${SCRIPT_DIR}/gtk.cfg ${ISOFILES_DIR}/isolinux/gtk.cfg
cp ${SCRIPT_DIR}/drkgtk.cfg ${ISOFILES_DIR}/isolinux/drkgtk.cfg
cp ${SCRIPT_DIR}/menu.cfg ${ISOFILES_DIR}/isolinux/menu.cfg
cp ${SCRIPT_DIR}/grub.cfg ${ISOFILES_DIR}/boot/grub/grub.cfg
chmod 0444 ${ISOFILES_DIR}/isolinux/* || true

# Step 11: Update MD5 checksums
echo "===> Step 11: Updating MD5 checksums"
cd "${ISOFILES_DIR}"
chmod +w md5sum.txt
# Don't follow symlinks (-follow causes filesystem loops)
# Some files may fail (symlinks, special files) - continue anyway
find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt 2>&1 || true
chmod -w md5sum.txt
cd "${SCRIPT_DIR}"

# Step 12: Build final ISO
echo "===> Step 12: Building final ISO"
# Volume ID: max 16 chars for Joliet (PF- prefix + 13 chars)
VERSION_SHORT="${PF_VERSION##*/}"
VERSION_SHORT="${VERSION_SHORT:0:13}"
VOLID="PF-${VERSION_SHORT}"
xorriso -as mkisofs \
    -r -J -joliet-long \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -isohybrid-apm-hfsplus \
    -V "${VOLID}" \
    -o ${ISO_OUT} \
    ${ISOFILES_DIR}

echo "=============================================="
echo "USB Bootable ISO created successfully!"
echo "Output: ${ISO_OUT}"
echo "Size: $(du -h ${ISO_OUT} | cut -f1)"
echo "=============================================="
