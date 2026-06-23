#!/bin/bash

#This is will attempt to install all the packages
#from the spec file using just packetfence repo
#

PFDIR=${PFDIR:-/usr/local/pf}
SPEC=${SPEC:-"$PFDIR/rpm/packetfence.spec"}
REPO=${REPO:-packetfence}
PF_REPO="--enablerepo=$REPO"

if [ ! -x /usr/bin/repoquery ];then
    echo "Package yum-utils is not installed to run"
    echo " yum install yum-utils"
    exit 1
fi

YUM="yum $PF_REPO -y"
$YUM makecache
echo installing the packetfence dependencies from the $REPO repo

REPOQUERY="repoquery --queryformat=%{NAME} $PF_REPO -c /etc/yum.conf -C --pkgnarrow=all"

EL_VERSION=$(cat /etc/redhat-release | perl -p -e's/^.*(\d+)\..*$/$1/' )

if [ ! -x /usr/bin/rpmspec ];then
    echo "Package rpm-build is not installed to run"
    echo "Using 'yum deplist' as a fallback"
    $YUM deplist packetfence \
    | awk '/provider:/ {print $2}' \
    | sort -u \
    | xargs $YUM install
else
    rpm -q -D"el$EL_VERSION 1" --requires  --specfile $SPEC \
    | grep -v 'fingerbank >' \
    | perl -p -e's/ +$//' | sort -u \
    | xargs -d '\n' $YUM install
fi
