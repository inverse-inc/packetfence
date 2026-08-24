#!/bin/bash
set -o nounset -o pipefail -o errexit

# DEBIAN_VERSION and DEBIAN_NETINST_SHA256 are provided as environment variables
# when running in Docker (see create-debian-installer-docker.sh). When running
# directly on the host, source them from the shared config file.
if [ -z "${DEBIAN_VERSION:-}" ]; then
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  source "${SCRIPT_DIR}/../debian-version.conf"
fi

function clean() {
  rm -fr isofiles/
  rm -f preseed.cfg
  chmod a+rw $ISO_IN
  chmod a+rw $ISO_OUT
}

ISO_IN=${ISO_IN:-debian-$DEBIAN_VERSION-amd64-netinst.iso}
ISO_OUT=${ISO_OUT:-packetfence-debian-installer.iso}

trap clean EXIT

# cdimage serves the current point release under release/ and moves it to
# archive/ once a newer one ships, so try both rather than pinning one tree and
# breaking every time Debian cuts a point release.
#
# Download to a .part file and only rename once the checksum matches: wget -O
# leaves a zero-byte file behind on failure, which the -f test above would then
# happily treat as a cached ISO on the next run.
if ! [ -f $ISO_IN ]; then
	fetched=no
	for tree in release archive; do
		if wget "https://cdimage.debian.org/cdimage/${tree}/${DEBIAN_VERSION}/amd64/iso-cd/${ISO_IN}" -O "${ISO_IN}.part"; then
			fetched=yes
			break
		fi
	done
	if [ "$fetched" != yes ]; then
		rm -f "${ISO_IN}.part"
		echo "ERROR: could not fetch ${ISO_IN} from cdimage.debian.org (tried release/ and archive/)." >&2
		exit 1
	fi
	# The ISO comes over plain HTTPS with no signature check, so verify the
	# checksum from ci/debian-version.conf before building an installer on it.
	if ! echo "${DEBIAN_NETINST_SHA256}  ${ISO_IN}.part" | sha256sum -c -; then
		rm -f "${ISO_IN}.part"
		echo "ERROR: checksum mismatch on ${ISO_IN}; refusing to build." >&2
		exit 1
	fi
	mv "${ISO_IN}.part" "$ISO_IN"
fi

rm -fr isofiles/

cat preseed.cfg.tmpl | sed "s/%%PF_VERSION%%/$PF_RELEASE/g"  > preseed.cfg

xorriso -osirrox on -indev $ISO_IN -extract / isofiles

chmod +w -R isofiles/install.amd/
gunzip isofiles/install.amd/initrd.gz
echo preseed.cfg | cpio -H newc -o -A -F isofiles/install.amd/initrd
gzip isofiles/install.amd/initrd
chmod -w -R isofiles/install.amd/

chmod a+w isofiles/isolinux/gtk.cfg isofiles/isolinux/drkgtk.cfg isofiles/boot/grub/grub.cfg
cp gtk.cfg isofiles/isolinux/gtk.cfg
cp drkgtk.cfg isofiles/isolinux/drkgtk.cfg
cp menu.cfg isofiles/isolinux/menu.cfg
cp grub.cfg isofiles/boot/grub/grub.cfg
chmod 0444 isofiles/isolinux/*

cp postinst-debian-installer.sh isofiles/
cd isofiles
chmod +w md5sum.txt
# The '|| echo' is there so that it always exits with 0 because find returns a non-zero status because there is debian symlink in isofiles that points to '.'
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt || echo
chmod -w md5sum.txt
cd ..

# occurences of -no-emul-boot are mandatory
xorriso -as mkisofs -r -J -joliet-long -b isolinux/isolinux.bin -c isolinux/boot.cat -boot-load-size 4 -boot-info-table  -no-emul-boot -o $ISO_OUT -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus -V "Packetfence $PF_RELEASE" isofiles
