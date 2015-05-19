#!/bin/bash

#This is will attempt to install all the packages
#from the spec file using just packetfence-devel repo
#

PFDIR=/usr/local/pf
SPEC="$PFDIR/addons/packages/packetfence.spec"
REPO=packetfence-devel

YUM="yum --disablerepo=* --enablerepo=$REPO -y"
$YUM makecache
echo installing the packetfence dependencies from the $REPO repo

REPOQUERY="repoquery --queryformat=%{NAME} --disablerepo=* --enablerepo=$REPO -c /etc/yum.conf -C --pkgnarrow=all"

rpm -q --requires --specfile $SPEC | grep -v packetfence \
    | perl -pi -e's/ +$//' | sort -u \
    | xargs -d '\n' $REPOQUERY --whatprovides \
    | sort -u | grep -v perl-LDAP \
    | xargs $YUM -C install
