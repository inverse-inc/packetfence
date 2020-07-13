#!/bin/bash
set -o nounset -o pipefail -o errexit

echo "#################################"
echo "  Running Switch Post Config (config_switch.sh)"
echo "#################################"
sudo su

# Config for OOB Switch

# Warning: bridge and sub bridge interfaces will inherit MAC address
# from *first* port in bridge.
# Consequently, swp48 is used here to make DHCP lease obtained from libvirt
# still working after interfaces remap and reboot.
cat <<EOT > /etc/network/interfaces
auto lo
iface lo inet loopback

auto bridge
iface bridge
    bridge-vlan-aware yes
    bridge-ports swp48 swp1 swp2 swp3 swp6 swp11 swp12 swp13
    bridge-vids 2 3 6 17 100
    bridge-pvid 1

auto swp1
iface swp1
    bridge-access 17

auto swp2
iface swp2
    bridge-access 2

auto swp3
iface swp3
    bridge-access 3

auto swp6
iface swp6
    bridge-access 6

auto swp11
iface swp11
    bridge-access 17

auto swp13
iface swp13
    bridge-access 6

auto swp48
iface swp48
    bridge-access 100

auto bridge.17
iface bridge.17
    alias Management
    address 172.17.17.201/24

auto bridge.100
iface bridge.100 inet dhcp
    alias Internet (used by Vagrant)
    
EOT

echo "#################################"
echo "   Finished"
echo "#################################"
