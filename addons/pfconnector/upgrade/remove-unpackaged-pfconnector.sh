#!/bin/bash

set -o nounset -o pipefail -o errexit

pfconnector_unpackaged_installed=0

function check_existing_install() {
    if [ -f "/usr/local/bin/pfconnector" ]; then
        echo "Unpackaged PacketFence Connector detected"
        echo "Will perform a cleanup before doing packaged installation"
        pfconnector_unpackaged_installed=1
    else
        echo "No unpackaged PacketFence Connector detected"
    fi
}

function cleanup() {
    echo "Removing unpackaged installation"
    # existing systemd unit is not removed because it will be overwritten by package installation
    # stop service to remove binary
    systemctl stop packetfence-pfconnector-remote
    rm -fv /usr/local/bin/pfconnector-configure
    rm -fv /usr/local/bin/pfconnector
}

function import_conf() {
    echo "Importing existing configuration"
    mv -fv /etc/pfconnector-client.env /usr/local/pfconnector-remote/conf/pfconnector-client.env
    # use same permissions as for new package
    chmod 600 /usr/local/pfconnector-remote/conf/pfconnector-client.env
}


check_existing_install
if [ "$pfconnector_unpackaged_installed" -eq 1 ]; then
    cleanup
    import_conf
fi
