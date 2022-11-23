#!/bin/bash
set -o nounset -o pipefail -o errexit

# /target is the chroot point used by Debian installer
# all below commands are run inside it from BusyBox

# need cgroupfs-mount package installed
# necessary to run Docker daemon
/usr/bin/cgroupfs-mount

# load overlay module to use overlay2 storage driver with Docker daemon
modprobe overlay

# run containerd
/usr/bin/containerd &

# run Docker daemon
/usr/bin/dockerd --iptables=false -s overlay2 &


