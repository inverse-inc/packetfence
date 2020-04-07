#!/bin/bash
set -o nounset -o pipefail

VENOM_BIN_PATH=/usr/bin
VENOM_BINARY=venom
ROOTUSER_NAME=root

install_venom() {
    local venom_repo_url=https://api.github.com/repos/ovh/venom/releases/latest
    local venom_download_url=$(curl -s ${venom_repo_url}|grep "browser_download_url.*linux-amd64*"|cut -d '"' -f 4)
    echo "Installing Venom in ${VENOM_BIN_PATH}/${VENOM_BINARY}"
    curl -L -s ${venom_download_url} -o ${VENOM_BIN_PATH}/${VENOM_BINARY}
    if [ "$?" -ne 0 ]; then
        echo "Error installing Venom"
        exit 2
    else
        chmod +x ${VENOM_BIN_PATH}/${VENOM_BINARY}
    fi
}

username=$(id -nu)                           # Who is running this script?
if [ "$username" != "$ROOTUSER_NAME" ]
then
  echo "This script must run as root or with root privileges."
  exit 1
fi

if [ -f ${VENOM_BIN_PATH}/${VENOM_BINARY} ]; then
    echo "Venom already installed, nothing to do"
    exit 0
else
    if type curl 2> /dev/null; then
        install_venom
    else
        echo "Install curl before running this script"
        exit 0
    fi
fi
exit 0
