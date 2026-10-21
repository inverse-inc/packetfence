#!/bin/bash
set -o nounset -o pipefail -o errexit

cd /cd-iso

apt update
apt install xorriso wget cpio -yqq

./create-debian-installer.sh

