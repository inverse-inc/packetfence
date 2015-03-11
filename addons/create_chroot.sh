NS=$1
BASE=$2

if [ -z "$NS" ] || [ -z "$BASE" ]; then
    echo "Missing parameter"
    exit 1;
fi

[ -d $BASE/$NS ]                || mkdir $BASE/$NS
[ -d $BASE/$NS/proc ]           || mkdir $BASE/$NS/proc
[ -d $BASE/$NS/var ]            || mkdir $BASE/$NS/var
[ -d $BASE/$NS/etc ]            || mkdir $BASE/$NS/etc
[ -d $BASE/$NS/lib ]            || mkdir $BASE/$NS/lib
[ -d $BASE/$NS/lib64 ]          || mkdir $BASE/$NS/lib64
[ -d $BASE/$NS/usr ]            || mkdir $BASE/$NS/usr
[ -d $BASE/$NS/sbin ]           || mkdir $BASE/$NS/sbin
[ -d $BASE/$NS/bin ]            || mkdir $BASE/$NS/bin
[ -d $BASE/$NS/var/cache ]      || mkdir $BASE/$NS/var/cache
[ -d $BASE/$NS/sys ]            || mkdir $BASE/$NS/sys
[ -d $BASE/$NS/var/lib/samba ]  || mkdir -p $BASE/$NS/var/lib/samba
[ -d $BASE/$NS/dev ]            || mkdir $BASE/$NS/dev

cp -fr /var/cache/samba$NS $BASE/$NS/var/cache/

mount -o bind /proc           $BASE/$NS/proc/
mount -o bind /etc            $BASE/$NS/etc
mount -o bind /lib            $BASE/$NS/lib
mount -o bind /lib64          $BASE/$NS/lib64
mount -o bind /bin            $BASE/$NS/bin
mount -o bind /usr            $BASE/$NS/usr
mount -o bind /sbin           $BASE/$NS/sbin
mount -o bind /sys            $BASE/$NS/sys
mount -o bind /var/lib/samba/ $BASE/$NS/var/lib/samba/
mount -o bind /dev/           $BASE/$NS/dev
