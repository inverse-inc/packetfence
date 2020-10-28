#!/bin/bash
set -o nounset -o pipefail

VENOM_BIN_PATH=/usr/bin
VENOM_BINARY=venom
ROOTUSER_NAME=root
VENOM_LATEST_URL=https://api.github.com/repos/ovh/venom/releases/latest
VENOM_DEFAULT_VERSION="0.27.0"
VENOM_INSTALL_VERSION=${VENOM_VERSION:-${VENOM_DEFAULT_VERSION}}
VENOM_LATEST_VERSION=""
VENOM_INSTALLED_VERSION=""
VENOM_DIFF_VERSION=""
INSTALL_BOO=0
# Usage: VENOM_VERSION=0.28.0 ./install-venom.sh
# Check requirements
## Who is running this script? If not root escape the installation
username=$(id -nu)
if [ "$username" != "$ROOTUSER_NAME" ]; then
  echo "This script must run as root or with root privileges."
  exit 1
fi
## Is curl Installed
if [ ! type curl 2> /dev/null ] ; then
  echo "Install curl before running this script"
  exit 1
fi

# Install Venom
install_venom() {
  echo "Installing Venom in ${VENOM_BIN_PATH}/${VENOM_BINARY}"
  curl -L -s https://github.com/ovh/venom/releases/download/v${VENOM_INSTALL_VERSION}/venom.linux-amd64 -o ${VENOM_BIN_PATH}/${VENOM_BINARY}
  if [ "$?" -ne 0 ]; then
    echo "Error installing Venom"
    exit 2
  else
    chmod +x ${VENOM_BIN_PATH}/${VENOM_BINARY}
  fi
}

# Compare Versions
compare_version_numbers() {
  # Source: https://github.com/yousefvand/shellman
  # Licence MIT
  declare -a v1_array=(${VENOM_INSTALLED_VERSION//./ })
  declare -a v2_array=(${VENOM_INSTALL_VERSION//./ })

  if [[ "${#v1_array[@]}" -gt "${#v2_array[@]}" ]]; then
     while [[ "${#v2_array[@]}" -ne "${#v1_array[@]}" ]];do
       v2_array+=("0")
     done
  elif [[ "${#v1_array[@]}" -lt "${#v2_array[@]}" ]]; then
     while [[ "${#v2_array[@]}" -ne "${#v1_array[@]}" ]];do
       v1_array+=("0")
     done
  fi

  while [[ "${#v1_array[@]}" -gt "0" || "${#v2_array[@]}" -gt "0" ]] ; do
    let v1_val=${v1_array:-0}
    let v2_val=${v2_array:-0}
    let result=$((v1_val-v2_val))

    if (( result != 0 )); then
      VENOM_DIFF_VERSION=$result
      return
    fi

    v1_array=("${v1_array[@]:1}")
    v2_array=("${v2_array[@]:1}")
  done

  VENOM_DIFF_VERSION=0
  return
}

# Test if latest version
if [[ ${VENOM_INSTALL_VERSION} == "latest" ]]; then
  VENOM_INSTALL_VERSION=$(curl -s ${VENOM_LATEST_URL} | grep 'tag_name.*' | cut -d '"' -f 4 | grep -oP '\d.*')
fi

# Test versions
if [ -f ${VENOM_BIN_PATH}/${VENOM_BINARY} ]; then
  VENOM_INSTALLED_VERSION=$(venom version | grep -oP 'v\d.*' | grep -oP '\d.*' )

  if [ -n ${VENOM_INSTALLED_VERSION} ] && [ -n ${VENOM_INSTALL_VERSION} ]; then
    compare_version_numbers
  else
    echo "Error extracting Venom versions"
    exit 2
  fi

  if [ "${VENOM_DIFF_VERSION}" -eq "0" ]; then
    INSTALL_BOO=1
    echo "Venom already installed with the same version v${VENOM_INSTALLED_VERSION}, nothing to do."
  fi
fi

if [ "${INSTALL_BOO}" -eq "0" ] ; then
  echo "Venom (version v${VENOM_INSTALL_VERSION}) is going to be installed."
  install_venom
fi
exit 0
