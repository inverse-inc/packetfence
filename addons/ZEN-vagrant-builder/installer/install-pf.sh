#!/bin/bash

echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Install the PacketFence repos
yum localinstall http://packetfence.org/downloads/PacketFence/RHEL7/packetfence-release-7.stable.noarch.rpm -y

# Utils installation
yum install ntpd -y

# PacketFence installation
yum install perl -y
yum install --enablerepo=$PFREPO $PFPACKAGE -y

# Setting the hostname
hostname packetfence
echo "packetfence" > /etc/hostname
echo "NETWORKING=yes HOSTNAME=packetfence" > /etc/sysconfig/network

# Setting up rc.local so it modifies /etc/issue to display instructions on setting up the ZEN
cat /vagrant/installer/rc.local > /etc/rc.local

# Systemd won't execute /etc/rc.local unless we do this
chmod +x /etc/rc.d/rc.local

# Set the root password
echo "p@ck3tf3nc3" | passwd root --stdin

# Enable password authentication for SSH
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config

# Put the demo user insert statement into the schema file
cat <<EOT >> /usr/local/pf/db/pf-schema.sql
--
-- Insert the demo user for testing
--

INSERT INTO password (pid, password, valid_from, expiration, access_duration, access_level, category) VALUES ('demouser', 'demouser', NOW(), '2038-01-01', '1D', NULL, 1);

EOT
