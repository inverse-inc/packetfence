#!/bin/bash
NS=$1
BASE=$2

if [ -z "$NS" ] || [ -z "$BASE" ]; then
    echo "Missing parameter"
    exit 1;
fi

DIRS=(proc var etc lib lib64 usr sbin bin var/cache sys var/lib/samba dev tmp run/samba var/log/samba var/lock)

for dir in "${DIRS[@]}"; do
  [ -d $BASE/$NS/$dir ]                || mkdir -p $BASE/$NS/$dir
done

touch /var/cache/samba$NS/secrets.tdb
cp -fr /var/cache/samba$NS $BASE/$NS/var/cache/

DIRS=(proc etc lib lib64 bin usr sbin sys var/lib/samba dev var/log/samba var/lock)

MOUNTS=(`mount | awk '{print $3}'`)

for dir in "${DIRS[@]}"; do
  value=$BASE/$NS/$dir
  if [[ ! " ${MOUNTS[@]} " =~ " ${value} " ]]; then
    mount -o bind /$dir           $BASE/$NS/$dir
  fi
done

