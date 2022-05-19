#!/bin/bash
set -o nounset -o pipefail -o errexit

function clean() {
  rm -fr isofiles/
  rm -f preseed.cfg
  chmod a+rw $ISO_IN
  chmod a+rw $ISO_OUT
}

ISO_IN=${ISO_IN:-debian-11.3.0-amd64-netinst.iso}
ISO_OUT=${ISO_OUT:-packetfence-debian-installer.iso}

if ! [ -f $ISO_IN ]; then
	wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$ISO_IN
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
cp gtk.cfg isofiles/isolinux/drkgtk.cfg
cp grub.cfg isofiles/boot/grub/grub.cfg
chmod 0444 isofiles/isolinux/gtk.cfg isofiles/isolinux/drkgtk.cfg isofiles/boot/grub/grub.cfg

cd isofiles
chmod +w md5sum.txt
# The '|| echo' is there so that it always exits with 0 because find returns a non-zero status because there is debian symlink in isofiles that points to '.'
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt || echo
chmod -w md5sum.txt
cd ..

genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $ISO_OUT isofiles

clean
