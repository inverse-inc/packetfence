#!/bin/bash
NS=$1
BASE=$2

#May be needed later on to differenciate CentOS and Debian. Useless now since CentOS code is the same for RHEL6 and RHEL7
#if [ -e /etc/redhat-release ]; then
#    RHEL=$(cat /etc/redhat-release | grep -Eo "[0-9]+(\.[0-9]+)*" | cut -d '.' -f1);
#fi

if [ -z "$NS" ] || [ -z "$BASE" ]; then
    echo "Missing parameters. First is NS second is BASE."
    exit 1;
fi

DIRS=(proc var etc lib lib64 usr sbin bin var/cache/samba sys var/lib/samba dev tmp run/samba var/log/samba)

for dir in "${DIRS[@]}"; do
  [ -d $BASE/$NS/$dir ]                || mkdir -p $BASE/$NS/$dir
done

DIRS=(proc lib lib64 bin usr sbin sys dev var/log/samba)

MOUNTS=(`mount | awk '{print $3}'`)

for dir in "${DIRS[@]}"; do
    value=$BASE/$NS/$dir
    if [[ ! " ${MOUNTS[@]} " =~ " ${value} " ]]; then
        mount -o bind /$dir $BASE/$NS/$dir
        if [ ! -f $BASE/$NS/$dir/resolv.conf ]; then
            ETC_DIRS=$(find /etc -maxdepth 1 -type d|tail -n+2);
            ETC_FILES=$(find /etc -maxdepth 1 -type f|grep -v resolv.conf)
            echo "$ETC_DIRS"|while read etc_dir;
            do
                if [ ! -d "/$BASE/$NS$etc_dir" ]; then
                    mkdir -p /$BASE/$NS$etc_dir;
                    mount -o bind $etc_dir /$BASE/$NS$etc_dir;
                fi
            done
            echo "$ETC_FILES"|while read etc_file; do yes 2>/dev/null|cp $etc_file /$BASE/$NS$etc_file; done
            cp /etc/netns/$NS/resolv.conf /$BASE/$NS/etc
        fi
    fi
done

