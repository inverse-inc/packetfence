#!/bin/bash
# Stage 3 internals: assemble the final USB-bootable ISO.
# Designed to run inside a debian:bookworm container as root, but works on
# the host too. Inputs (base DVD, repo, docker images) must already exist.
#
# Required env / args:
#   ISO_IN           base Debian DVD ISO path (file)
#   REPO_DIR         offline APT repo (directory) — produced by stage 2
#   DOCKER_IMAGES_DIR  pre-pulled Docker image archive directory — produced by stage 1
#   ISOFILES_DIR     scratch directory for extracted ISO contents
#   ISO_OUT          output ISO path
#   PF_VERSION, PF_RELEASE, PF_RELEASE_VERSION   version info
#   SCRIPT_DIR       directory containing preseed-offline.cfg.tmpl, *.cfg, postinst-offline.sh
set -o nounset -o pipefail -o errexit

: "${ISO_IN:?ISO_IN must be set}"
: "${REPO_DIR:?REPO_DIR must be set}"
: "${DOCKER_IMAGES_DIR:?DOCKER_IMAGES_DIR must be set}"
: "${ISOFILES_DIR:?ISOFILES_DIR must be set}"
: "${ISO_OUT:?ISO_OUT must be set}"
: "${PF_VERSION:?PF_VERSION must be set}"
: "${PF_RELEASE:?PF_RELEASE must be set}"
: "${PF_RELEASE_VERSION:?PF_RELEASE_VERSION must be set}"
: "${SCRIPT_DIR:?SCRIPT_DIR must be set}"

echo "=============================================="
echo "Assembling USB Bootable ISO"
echo "=============================================="
echo "ISO_IN:             ${ISO_IN}"
echo "REPO_DIR:           ${REPO_DIR}"
echo "DOCKER_IMAGES_DIR:  ${DOCKER_IMAGES_DIR}"
echo "ISOFILES_DIR:       ${ISOFILES_DIR}"
echo "ISO_OUT:            ${ISO_OUT}"
echo "=============================================="

mkdir -p "${ISOFILES_DIR}"

# Step 1: Extract base ISO
echo "===> Step 1: Extracting base ISO"
rm -rf "${ISOFILES_DIR:?}"/*
xorriso -osirrox on -indev "${ISO_IN}" -extract / "${ISOFILES_DIR}"

# Step 2: Generate preseed configuration
# Write to a writable scratch dir — SCRIPT_DIR may be a read-only bind mount in CI.
PRESEED_STAGING=$(mktemp -d)
trap 'rm -rf "${PRESEED_STAGING}"' EXIT
echo "===> Step 2: Generating preseed configuration"
sed -e "s/%%PF_VERSION%%/${PF_RELEASE_VERSION}/g" \
    -e "s/%%PF_RELEASE%%/${PF_RELEASE}/g" \
    "${SCRIPT_DIR}/preseed-offline.cfg.tmpl" > "${PRESEED_STAGING}/preseed.cfg"

# Step 3: Inject preseed into initrd
echo "===> Step 3: Injecting preseed into initrd"
chmod +w -R "${ISOFILES_DIR}/install.amd/"
gunzip "${ISOFILES_DIR}/install.amd/initrd.gz"
( cd "${PRESEED_STAGING}" && echo preseed.cfg | cpio -H newc -o -A -F "${ISOFILES_DIR}/install.amd/initrd" )
gzip "${ISOFILES_DIR}/install.amd/initrd"
chmod -w -R "${ISOFILES_DIR}/install.amd/"

# Step 4: Add local repository to ISO
echo "===> Step 4: Adding local repository to ISO"
mkdir -p "${ISOFILES_DIR}/pf-repo"
cp -r "${REPO_DIR}"/* "${ISOFILES_DIR}/pf-repo/"

# Step 5: Add Docker images to ISO
echo "===> Step 5: Adding Docker images to ISO"
mkdir -p "${ISOFILES_DIR}/docker-images"
cp -r "${DOCKER_IMAGES_DIR}"/* "${ISOFILES_DIR}/docker-images/"

# Step 6: Copy post-installation script
echo "===> Step 6: Adding post-installation script"
cp "${SCRIPT_DIR}/postinst-offline.sh" "${ISOFILES_DIR}/"

# Step 7: Update boot configurations
echo "===> Step 7: Updating boot configurations"
chmod a+w "${ISOFILES_DIR}/isolinux/gtk.cfg" "${ISOFILES_DIR}/isolinux/drkgtk.cfg" \
    "${ISOFILES_DIR}/isolinux/menu.cfg" "${ISOFILES_DIR}/boot/grub/grub.cfg" || true
cp "${SCRIPT_DIR}/gtk.cfg"    "${ISOFILES_DIR}/isolinux/gtk.cfg"
cp "${SCRIPT_DIR}/drkgtk.cfg" "${ISOFILES_DIR}/isolinux/drkgtk.cfg"
cp "${SCRIPT_DIR}/menu.cfg"   "${ISOFILES_DIR}/isolinux/menu.cfg"
cp "${SCRIPT_DIR}/grub.cfg"   "${ISOFILES_DIR}/boot/grub/grub.cfg"
chmod 0444 "${ISOFILES_DIR}"/isolinux/* || true

# Step 8: Update MD5 checksums
echo "===> Step 8: Updating MD5 checksums"
( cd "${ISOFILES_DIR}"
  chmod +w md5sum.txt
  find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt 2>&1 || true
  chmod -w md5sum.txt
)

# Step 9: Build final ISO (hybrid, BIOS+UEFI bootable)
echo "===> Step 9: Building final ISO"
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
    -o "${ISO_OUT}" \
    "${ISOFILES_DIR}"

echo "=============================================="
echo "USB Bootable ISO created: ${ISO_OUT}"
echo "Size: $(du -h "${ISO_OUT}" | cut -f1)"
echo "=============================================="
