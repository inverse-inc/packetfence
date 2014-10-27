#!/bin/bash
# Creates a chroot environment that it suitable for testing
#
# Copyright (C) 2005-2014 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#
#

if [ -z "$1" ];then
    echo "Usage: $0 CHROOT_DIR"
    exit 1
fi 

PFDIR=/usr/local/pf
CHROOT_TOOLS=$PFDIR/addons/dev-helpers/centos-chroot/

CHROOT_NAME="$1"

CHROOT=/var/chroot/$CHROOT_NAME
ARCH=$(uname -m)

#Removing any old mounted filesystems

for d in proc dev
do
    MPOINT=$CHROOT/$d
    if  mountpoint -q "$MPOINT" ;then
        umount "$MPOINT"
        if [ $? != 0 ];then
            echo cannot umount $MPOINT
            exit 1
        fi
    fi
done

if [ -d $CHROOT ];then
    rm -rf $CHROOT
    if [ $? != 0 ];then
        echo cannot delete $CHROOT
        exit
    fi
fi
 
mkdir -p $CHROOT/tmp

if [ $? != 0 ];then
    echo cannot create $CHROOT
    exit
fi
 
rpm --initdb --root=$CHROOT

pushd $CHROOT/tmp
yumdownloader centos-release
wget "http://packetfence.org/downloads/PacketFence/RHEL6/`uname -i`/RPMS/packetfence-release-1-1.el6.noarch.rpm"
popd
rpm -i --root=$CHROOT --nodeps $CHROOT/tmp/*rpm
YUM="yum --installroot=$CHROOT --enablerepo=packetfence* -q -y"
echo installing the yum in the chroot
$YUM install yum 
echo installing the packetfence dependecies

REPOQUERY="repoquery --queryformat=%{NAME} --enablerepo=packetfence* -c $CHROOT/etc/yum.conf --tempcache --pkgnarrow=all"

rpm -q --requires --specfile $PFDIR/addons/packages/packetfence.spec | grep -v packetfence | sort -u | perl -pi -e's/\s*$/\n/' | xargs -d '\n' $REPOQUERY --whatprovides | sort -u | xargs -d '\n' $REPOQUERY --requires --resolve git gcc | sort -u | grep -v packetfence | xargs $YUM install


#repoquery -c $CHROOT/etc/yum.conf --queryformat='%{NAME}' --tempcache --pkgnarrow=all --requires --archlist=${ARCH},noarch --resolve --alldeps packetfence git yum-utils vim gcc | grep -v packetfence | xargs $YUM install
 
mkdir -p $CHROOT/root
cp $CHROOT/etc/skel/.??* $CHROOT/root

cp /etc/resolv.conf $CHROOT/etc/resolv.conf
cp /etc/sysconfig/network $CHROOT/etc/sysconfig/network
cp -r $CHROOT_TOOLS $CHROOT/chroot-tools

for d in proc dev
do
    mkdir -p $CHROOT/$d
    mount --bind /$d $CHROOT/$d
done

chroot $CHROOT bash /chroot-tools/init-chroot.sh
