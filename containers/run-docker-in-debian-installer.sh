#!/bin/bash
set -o nounset -o pipefail -o errexit

# /target is the chroot point used by Debian installer
# all below commands are run inside it from BusyBox

# generate an empty daemon.json to ignore Docker config inside
# Debian installer and use only CLI arguments
echo "{}" > /tmp/daemon.json

# need cgroupfs-mount package installed
# necessary to run Docker daemon
/usr/bin/cgroupfs-mount

# load overlay module to use overlay2 storage driver with Docker daemon
modprobe overlay

# run containerd
/usr/bin/containerd &

# run Docker daemon
/usr/bin/dockerd -b=none --config-file=/tmp/daemon.json --iptables=false -s overlay2 &


