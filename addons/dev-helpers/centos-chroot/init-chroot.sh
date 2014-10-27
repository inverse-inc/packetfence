#!/bin/bash
cd /chroot-tools

PFDIR=/usr/local/pf

BRANCH=devel

cp -f my.cnf /etc/

service mysqld start

mysql -uroot < init-pf-db.sql

adduser pf

git clone -b $BRANCH https://github.com/inverse-inc/packetfence.git $PFDIR

cat <<EOF >> $PFDIR/conf/pf.conf
[interface eth0]
ip=$(ip addr show dev eth0 | grep -Poh '(?<=inet )\d+(\.\d+){3}')
type=management
mask=$(ipcalc -4 -m $(ip addr show dev eth0 | grep -Poh '(?<=inet )\d+(\.\d+){3}\/\d+') | perl -pi -e's/^.*=//')
EOF

cd $PFDIR
make devel

mysql -uroot pf < db/pf-schema.sql

./bin/pfcmd configreload hard


