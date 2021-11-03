#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}

# create /usr/local/pf in container to make pfconfig happy
ln -s ${PF_SRC_DIR} /usr/local/pf

# only install packetfence dependencies
# will install packetfence-perl
${PF_SRC_DIR}/addons/dev-helpers/debian/install-pf-dependencies.sh

# pf is not installed, need to create manually PF user
useradd pf

make -C ${PF_SRC_DIR} devel

# run pfconfig as daemon
/usr/local/pf/sbin/pfconfig -d 
