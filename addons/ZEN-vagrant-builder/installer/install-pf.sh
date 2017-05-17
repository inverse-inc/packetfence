#!/bin/bash

echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Install the PacketFence repos
yum localinstall http://packetfence.org/downloads/PacketFence/RHEL7/`uname -i`/RPMS/packetfence-release-1.2-6.el7.centos.noarch.rpm -y

# Update the release to be sure we run its latest version
yum update packetfence-release --enablerepo=packetfence -y

# PacketFence installation
yum install perl -y
yum install --enablerepo=$PFREPO $PFPACKAGE -y

# Setting the hostname
hostname PacketFence-ZEN
echo "PacketFence-ZEN" > /etc/hostname
echo "NETWORKING=yes HOSTNAME=PacketFence-ZEN" > /etc/sysconfig/network

# Setting up rc.local so it modifies /etc/issue to display instructions on setting up the ZEN
cat /vagrant/installer/rc.local > /etc/rc.local

# Systemd won't execute /etc/rc.local unless we do this
chmod +x /etc/rc.d/rc.local

# Set the root password
echo "p@ck3tf3nc3" | passwd root --stdin

# Enable password authentication for SSH
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config

