#!/bin/bash

cat /vagrant/installer/rc.local > /etc/rc.local

#repo used for the initial install of PacketFence
cp /vagrant/installer/packetfence.repo /etc/yum.repos.d/

yum install perl -y
yum install --enablerepo=packetfence-devel packetfence -y

hostname PacketFence-ZEN
echo "PacketFence-ZEN" > /etc/hostname
echo "NETWORKING=yes HOSTNAME=PacketFence-ZEN" > /etc/sysconfig/network

chmod +x /etc/rc.d/rc.local

# Set the root password
echo "p@ck3tf3nc3" | passwd root --stdin

# Enable password authentication
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config

