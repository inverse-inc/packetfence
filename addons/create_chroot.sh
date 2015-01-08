NS=$1

[ -d /chroots/$NS ] || mkdir /chroots/$NS
[ -d /chroots/$NS/proc ] || mkdir /chroots/$NS/proc
[ -d /chroots/$NS/var ] || mkdir /chroots/$NS/var
[ -d /chroots/$NS/etc ] || mkdir /chroots/$NS/etc
[ -d /chroots/$NS/lib ] || mkdir /chroots/$NS/lib
[ -d /chroots/$NS/lib64 ] || mkdir /chroots/$NS/lib64
[ -d /chroots/$NS/usr ] || mkdir /chroots/$NS/usr
[ -d /chroots/$NS/sbin ] || mkdir /chroots/$NS/sbin
[ -d /chroots/$NS/bin ] || mkdir /chroots/$NS/bin
[ -d /chroots/$NS/var/cache ] || mkdir /chroots/$NS/var/cache
[ -d /chroots/$NS/sys ] || mkdir /chroots/$NS/sys
[ -d /chroots/$NS/var/lib/samba ] || mkdir -p /chroots/$NS/var/lib/samba
[ -d /chroots/$NS/dev ] || mkdir /chroots/$NS/dev

cp -fr /var/cache/samba$NS /chroots/$NS/var/cache/

mount -o bind /proc /chroots/$NS/proc/
mount -o bind /etc /chroots/$NS/etc
mount -o bind /lib /chroots/$NS/lib
mount -o bind /lib64 /chroots/$NS/lib64
mount -o bind /bin /chroots/$NS/bin
mount -o bind /usr /chroots/$NS/usr
mount -o bind /sbin /chroots/$NS/sbin
mount -o bind /sys /chroots/$NS/sys
mount -o bind /var/lib/samba/ /chroots/$NS/var/lib/samba/
mount -o bind /dev/ /chroots/$NS/dev
