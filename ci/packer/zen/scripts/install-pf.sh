#!/bin/bash
set -o nounset -o pipefail -o errexit

# Variables are set using environment variables

echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Install the PacketFence repos
yum localinstall http://packetfence.org/downloads/PacketFence/RHEL7/packetfence-release-7.${PFBRANCH}.noarch.rpm -y

# Utils installation
yum install ntp e2fsprogs cloud-utils-growpart -y

# PacketFence installation
yum install perl -y
echo "Installing $PFPACKAGE from repo $PFREPO"
yum install --enablerepo=$PFREPO $PFPACKAGE -y

# Setting the hostname
hostname packetfence
echo "packetfence" > /etc/hostname
echo "NETWORKING=yes HOSTNAME=packetfence" > /etc/sysconfig/network

# Systemd won't execute /etc/rc.local unless we do this
chmod +x /etc/rc.d/rc.local

# Set the root password
echo "p@ck3tf3nc3" | passwd root --stdin

# Put the demo user insert statement into the schema file
cat <<EOT >> /usr/local/pf/db/pf-schema.sql
--
-- Insert the demo user for testing
--

INSERT INTO password (pid, password, valid_from, expiration, access_duration, access_level, category) VALUES ('demouser', 'demouser', NOW(), '2038-01-01', '1D', NULL, 1);

EOT
