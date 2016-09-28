#!/bin/bash
NS=$1
BASE=$2

if [ -z "$NS" ] || [ -z "$BASE" ]; then
    echo "Missing parameters. First is NS second is BASE."
    exit 1;
fi

ETC_DIRS=$(find /etc -maxdepth 1 -type d|tail -n+2|sed 's|/||')
DIRS=(proc var etc lib lib64 usr sbin bin var/cache/samba sys var/lib/samba dev tmp run/samba var/log/samba $ETC_DIRS)

for dir in "${DIRS[@]}"; do
  [ -d $BASE/$NS/$dir ]                || mkdir -p $BASE/$NS/$dir
done

DIRS=(proc lib lib64 bin usr sbin sys dev var/log/samba $ETC_DIRS)

MOUNTS=(`mount | awk '{print $3}'`)

for dir in "${DIRS[@]}"; do
    value=$BASE/$NS/$dir
    if [[ ! " ${MOUNTS[@]} " =~ " ${value} " ]]; then
        mount -o bind /$dir $BASE/$NS/$dir
    fi
done

ETC_FILES=$(find /etc -maxdepth 1 -type f|grep -v resolv.conf)
echo "$ETC_FILES"|while read etc_file; do yes 2>/dev/null|cp $etc_file /$BASE/$NS$etc_file; done
yes 2>/dev/null|cp /etc/netns/$NS/resolv.conf /$BASE/$NS/etc
