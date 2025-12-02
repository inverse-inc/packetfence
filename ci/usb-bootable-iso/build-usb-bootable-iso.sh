#!/bin/bash
set -o nounset -o pipefail -o errexit

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

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
ISO_IN=${ISO_IN:-debian-12.6.0-amd64-netinst.iso}
ISO_OUT=${ISO_OUT:-packetfence-usb-installer.iso}
WORK_DIR=${SCRIPT_DIR}/work
ISOFILES_DIR=${WORK_DIR}/isofiles
REPO_DIR=${WORK_DIR}/repo
DOCKER_IMAGES_DIR=${WORK_DIR}/docker-images

# Version info
PF_VERSION=${PF_VERSION:-$(cat "${PF_ROOT}/conf/pf-release" | cut -d' ' -f2)}
PF_RELEASE=${PF_RELEASE:-$(cat "${PF_ROOT}/conf/pf-release")}
PF_RELEASE_VERSION=${PF_RELEASE_VERSION:-$(echo $PF_RELEASE | sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g')}

echo "=============================================="
echo "Building USB Bootable ISO"
echo "=============================================="
echo "PF_VERSION: ${PF_VERSION}"
echo "PF_RELEASE: ${PF_RELEASE}"
echo "PF_RELEASE_VERSION: ${PF_RELEASE_VERSION}"
echo "ISO_OUT: ${ISO_OUT}"
echo "=============================================="

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f ${SCRIPT_DIR}/preseed-offline.cfg
    # Keep work directory for debugging if build fails
}
trap cleanup EXIT

# Create work directories
mkdir -p ${WORK_DIR}
mkdir -p ${ISOFILES_DIR}
mkdir -p ${REPO_DIR}
mkdir -p ${DOCKER_IMAGES_DIR}

# Step 1: Download base Debian ISO if not present
echo "===> Step 1: Checking base Debian ISO"
if ! [ -f ${SCRIPT_DIR}/${ISO_IN} ]; then
    echo "Downloading ${ISO_IN}... (this may take a few minutes)"
    wget -q https://cdimage.debian.org/cdimage/archive/12.6.0/amd64/iso-cd/${ISO_IN} -O ${SCRIPT_DIR}/${ISO_IN}
    echo "Download complete: $(du -h ${SCRIPT_DIR}/${ISO_IN} | cut -f1)"
else
    echo "Base ISO already present: ${ISO_IN}"
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
cat ${SCRIPT_DIR}/preseed-offline.cfg.tmpl | \
    sed "s/%%PF_VERSION%%/${PF_RELEASE_VERSION}/g" | \
    sed "s/%%PF_RELEASE%%/${PF_RELEASE}/g" > ${SCRIPT_DIR}/preseed-offline.cfg

# Step 6: Inject preseed into initrd
echo "===> Step 6: Injecting preseed into initrd"
chmod +w -R ${ISOFILES_DIR}/install.amd/
gunzip ${ISOFILES_DIR}/install.amd/initrd.gz
echo preseed-offline.cfg | cpio -H newc -o -A -F ${ISOFILES_DIR}/install.amd/initrd
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
cd ${ISOFILES_DIR}
chmod +w md5sum.txt
# Don't follow symlinks (-follow causes filesystem loops)
find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt 2>/dev/null || echo "MD5 generation completed with warnings"
chmod -w md5sum.txt
cd ${SCRIPT_DIR}

# Step 12: Build final ISO
echo "===> Step 12: Building final ISO"
# ISO 9660 volume ID: max 32 chars, Joliet: max 16 chars
# Format: PF-${short_name} (3 chars prefix + 13 chars max for Joliet compatibility)
if [[ "${PF_VERSION}" == *"/"* ]]; then
    VERSION_SHORT="${PF_VERSION##*/}"
    echo "Volume ID: extracted '${VERSION_SHORT}' from '${PF_VERSION}'"
else
    VERSION_SHORT="${PF_VERSION}"
    echo "Volume ID: using '${VERSION_SHORT}' (no slash found)"
fi
# Truncate to 13 characters to fit within 16 char Joliet limit with "PF-" prefix
VERSION_SHORT="${VERSION_SHORT:0:13}"
VOLID="PF-${VERSION_SHORT}"
echo "Volume ID: final value '${VOLID}' (${#VOLID} chars)"
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
