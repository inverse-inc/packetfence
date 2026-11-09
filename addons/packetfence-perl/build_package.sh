#!/bin/bash
set -o nounset -o pipefail -o errexit

WORKDIR="${WORKDIR:-/root}"
BASE_DIR="${BASE_DIR:-/usr/local/pf/lib/perl_modules}"
OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY:-/mnt/output/}"
SCRIPT_DIR=/build/packages

mkdir -p $SCRIPT_DIR
if [ ! -f /etc/debian_version ]; then
    echo "Not a Debian system, exit"
    exit 0
fi
PF_PERL_ARCHIVE=packetfence_perl_deb_module_without_all_path.tar.gz

cd "${BASE_DIR}"
tar cvfz $SCRIPT_DIR/$PF_PERL_ARCHIVE ./
cp -av /$WORKDIR/debian $SCRIPT_DIR
cd $SCRIPT_DIR
dpkg-buildpackage --no-sign -rfakeroot
mkdir -p /$OUTPUT_DIRECTORY/debian/packages 
#remove old packages
find /$OUTPUT_DIRECTORY/debian/packages/ -name "packetfence-perl*" -exec rm {} \;
cp -av ../packetfence-perl* /$OUTPUT_DIRECTORY/debian/packages
cd -
