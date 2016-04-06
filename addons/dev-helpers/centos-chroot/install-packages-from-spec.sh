#!/bin/bash

#This is will attempt to install all the packages
#from the spec file using just packetfence-devel repo
#

PFDIR=/usr/local/pf
SPEC="$PFDIR/addons/packages/packetfence.spec"
REPO=packetfence-devel
PF_REPO="--enablerepo=$REPO"
STD_REPOS="--enablerepo=base --enablerepo=updates --enablerepo=extras"

YUM="yum --disablerepo=* $PF_REPO $STD_REPOS -y"
$YUM makecache
echo installing the packetfence dependencies from the $REPO repo

REPOQUERY="repoquery --queryformat=%{NAME} --disablerepo=* $PF_REPO $STD_REPOS -c /etc/yum.conf -C --pkgnarrow=all"

EL_VERSION=$(cat /etc/redhat-release | perl -p -e's/^.*(\d+)\..*$/$1/' )

rpm -q -D"el$EL_VERSION 1" --requires  --specfile $SPEC | grep -v packetfence \
    | perl -pi -e's/ +$//' | sort -u \
    | xargs -d '\n' $REPOQUERY --whatprovides \
    | sort -u | grep -v perl-LDAP \
    | xargs $YUM install
