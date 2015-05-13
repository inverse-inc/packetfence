#!/bin/bash

PFDIR=/usr/local/pf

YUM="yum --disablerepo='*' --enablerepo=packetfence-devel -y --skip-broken"
$YUM makecache
echo installing the packetfence dependecies

REPOQUERY="repoquery --queryformat=%{NAME} --disablerepo='*' --enablerepo=packetfence-devel -c /etc/yum.conf -C --pkgnarrow=all"

rpm -q --requires --specfile $PFDIR/addons/packages/packetfence.spec | grep -v packetfence | perl -pi -e's/ +$//' | sort -u | xargs -d '\n' $REPOQUERY --whatprovides | sort -u | grep -v perl-LDAP | xargs $YUM install 
