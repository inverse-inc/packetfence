#!/bin/bash
set -o nounset -o pipefail -o errexit

function clean() {
  rm -fr isofiles/
  rm -f preseed.cfg
  chmod a+rw $ISO_IN
  chmod a+rw $ISO_OUT
}

ISO_IN=${ISO_IN:-debian-12.6.0-amd64-netinst.iso}
ISO_OUT=${ISO_OUT:-packetfence-debian-installer.iso}

trap clean EXIT

if ! [ -f $ISO_IN ]; then
	wget https://cdimage.debian.org/cdimage/archive/12.6.0/amd64/iso-cd/$ISO_IN
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
