#!/bin/bash
set -o nounset -o pipefail -o errexit

cd /debian-installer

apt update
apt install xorriso wget cpio genisoimage -yqq

./create-debian-installer.sh

