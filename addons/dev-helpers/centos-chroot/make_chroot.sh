#!/bin/bash
# Creates a chroot environment that it suitable for testing
#
# Copyright (C) 2005-2019 Inverse inc.
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

pushd $CHROOT/tmp &> /dev/null
yumdownloader centos-release
wget "http://packetfence.org/downloads/PacketFence/RHEL6/`uname -i`/RPMS/packetfence-release-1-1.el6.noarch.rpm"
popd
rpm -i --root=$CHROOT --nodeps $CHROOT/tmp/*rpm
YUM="yum --installroot=$CHROOT -y"
echo Updating the yum cache

$YUM makecache

echo installing the yum in the chroot
$YUM install yum yum-utils vim gcc git mysql-server xargs

mkdir -p $CHROOT/root
cp $CHROOT/etc/skel/.??* $CHROOT/root

for d in proc dev
do
    mkdir -p $CHROOT/$d
    mount --bind /$d $CHROOT/$d
done

cp /etc/resolv.conf $CHROOT/etc/resolv.conf
cp /etc/sysconfig/network $CHROOT/etc/sysconfig/network
cp -r $CHROOT_TOOLS $CHROOT/chroot-tools

exit

chroot $CHROOT bash /chroot-tools/init-chroot.sh
