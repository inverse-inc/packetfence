#!/bin/bash

PFDIR=/usr/local/pf

GIT_REPO=https://github.com/inverse-inc/packetfence.git

BRANCH=devel

git clone -b $BRANCH "$GIT_REPO" "$PFDIR"


cd /chroot-tools

bash install-packages-from-spec.sh

cp -f my.cnf /etc/

service mysqld start

mysql -uroot < init-pf-db.sql

adduser pf


cat <<EOF > $PFDIR/conf/pf.conf
[interface eth0]
ip=$(ip addr show dev eth0 | grep -Poh '(?<=inet )\d+(\.\d+){3}')
type=management
mask=$(ipcalc -4 -m $(ip addr show dev eth0 | grep -Poh '(?<=inet )\d+(\.\d+){3}\/\d+') | perl -pi -e's/^.*=//')
EOF

cd $PFDIR
make devel

mysql -uroot pf < db/pf-schema.sql

./sbin/pfconfig -d

./bin/pfcmd configreload hard

