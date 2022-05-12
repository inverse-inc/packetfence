#!/bin/bash

set -o nounset -o pipefail -o errexit

build_dir=$(mktemp -d)
cd $build_dir

wget https://go.dev/dl/go1.18.linux-amd64.tar.gz
tar -xzf go1.18.linux-amd64.tar.gz
PATH="$(pwd)/go/bin:$PATH"

git clone https://github.com/inverse-inc/packetfence
cd packetfence
git checkout feature/connector

cp conf/systemd/packetfence-pfconnector-remote.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable packetfence-pfconnector-remote.service
systemctl stop packetfence-pfconnector-remote.service

cd go/
make pfconnector
cp pfconnector /usr/local/bin/
cd -

cp addons/pfconnector/configure.sh /usr/local/bin/pfconnector-configure

chmod +x /usr/local/bin/pfconnector*

echo "Connector installation completed"
