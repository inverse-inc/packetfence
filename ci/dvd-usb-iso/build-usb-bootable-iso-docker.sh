#!/bin/bash
set -o nounset -o pipefail -o errexit

# Docker wrapper for building PacketFence USB Bootable ISO
# This ensures a clean Debian 13 environment for the build

echo "=========================================="
echo "PacketFence USB Bootable ISO Docker Builder"
echo "=========================================="

# Run the build inside a Debian 13 container
exec /dvd-usb-iso/build-usb-bootable-iso.sh
