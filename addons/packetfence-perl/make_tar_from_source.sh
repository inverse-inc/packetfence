#!/bin/bash
set -o nounset -o pipefail -o errexit

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
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

cd /usr/local/pf/lib/perl_modules
tar cvfz $SCRIPT_DIR/$PF_PERL_ARCHIVE ./
if [ "${RPM_BUILD}" -eq 1 ]; then
    cp -v $SCRIPT_DIR/$PF_PERL_ARCHIVE $SCRIPT_DIR/rhel8/SOURCES/
fi
