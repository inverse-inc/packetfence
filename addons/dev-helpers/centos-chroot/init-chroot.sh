#!/bin/bash

PFDIR=/usr/local/pf

GIT_REPO=https://github.com/inverse-inc/packetfence.git

BRANCH=devel

git clone -b $BRANCH "$GIT_REPO" "$PFDIR"


YUM="yum --enablerepo=packetfence --enablerepo=packetfence-devel -y"
$YUM makecache
echo installing the packetfence dependecies

REPOQUERY="repoquery --queryformat=%{NAME} --enablerepo=packetfence --enablerepo=packetfence-devel -c /etc/yum.conf -C --pkgnarrow=all"

rpm -q --requires --specfile $PFDIR/addons/packages/packetfence.spec | grep -v packetfence | perl -pi -e's/ +$//' | sort -u | xargs -d '\n' $REPOQUERY --whatprovides | sort -u | grep -v perl-LDAP | xargs $YUM install

cd /chroot-tools

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

./bin/pfcmd configreload hard


