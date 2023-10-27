#!/bin/bash
set -o nounset -o pipefail -o errexit

workdir="${WORKDIR:-/root}"

SCRIPT_DIR=/build/packages
mkdir -p $SCRIPT_DIR
RPM_BUILD=0

if [ -f /etc/debian_version ]; then
    echo "Debian system detected"
    PF_PERL_ARCHIVE=packetfence_perl_deb_module_without_all_path.tar.gz
elif [ -f /etc/redhat-release ]; then
    echo "EL system detected"
    PF_PERL_ARCHIVE=packetfence_perl_el_module_without_all_path.tar.gz
    RPM_BUILD=1
else
    echo "Unknown system, exit"
    exit 0
fi

cd "${BASE_DIR}"
tar cvfz $SCRIPT_DIR/$PF_PERL_ARCHIVE ./
if [ "${RPM_BUILD}" -eq 1 ]; then
    cp -v $SCRIPT_DIR/$PF_PERL_ARCHIVE $SCRIPT_DIR/rhel8/SOURCES/
fi

if [ -f /etc/debian_version ]; then
    cp -a /$workdir/debian $SCRIPT_DIR
    cd $SCRIPT_DIR
    dpkg-buildpackage --no-sign -rfakeroot
    mkdir -p /$OUTPUT_DIRECTORY/debian/packages 
    #remove old packages
    find /$OUTPUT_DIRECTORY/debian/packages/ -name "packetfence-perl*" -exec rm {} \;
    cp -a ../packetfence-perl* /$OUTPUT_DIRECTORY/debian/packages
    cd -
fi
