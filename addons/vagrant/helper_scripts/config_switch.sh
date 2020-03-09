#!/bin/bash

echo "#################################"
echo "  Running Switch Post Config (config_switch.sh)"
echo "#################################"
sudo su

# Config for OOB Switch
cat <<EOT > /etc/network/interfaces
auto lo
iface lo inet loopback

auto swp48
iface swp48 inet dhcp
    alias Interface used by Vagrant

# we bridge interfaces on VLAN17
# to use for Ansible provisioning
auto bridge1
iface bridge1
    alias Untagged Bridge VLAN 17
    bridge-ports swp1 swp11
    hwaddress a0:00:00:00:00:11
    address 172.17.1.201/24
    
EOT

echo "#################################"
echo "   Finished"
echo "#################################"
