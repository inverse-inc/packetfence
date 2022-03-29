#!/bin/bash
set -o nounset -o pipefail -o errexit

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

## Is npm Installed
if ! type npm 2> /dev/null ; then
  echo "Install npm before running this script"
  echo "You can follow instructions here: https://github.com/nodesource/distributions#table-of-contents"
  exit 1
fi

log_section "Stop services"
systemctl stop packetfence-mariadb packetfence-redis-cache
systemctl stop packetfence-config
/usr/local/pf/bin/pfcmd service pf stop

log_section "Replace /usr/local/pf by git repository"
mv /usr/local/pf /usr/local/pf-pkg
git clone https://github.com/inverse-inc/packetfence /usr/local/pf

log_section "Create all necessary files"

# to have all Perl dependencies at correct location
cp -r /usr/local/pf-pkg/lib_perl /usr/local/pf/

cd /usr/local/pf
make devel
make conf/ssl/server.pem
mkdir /usr/local/pf/var/ssl_mutex
# to keep settings set up during configurator
cp /usr/local/pf-pkg/conf/pf.conf conf/
cp /usr/local/pf-pkg/conf/pfconfig.conf conf/
cp /usr/local/pf-pkg/conf/networks.conf conf/
cp -r /usr/local/pf-pkg/conf/certmanager/ conf/
# to keep iptables rule for vagrant management
cp /usr/local/pf-pkg/conf/iptables.conf conf/

log_section "Build web admin"
cd /usr/local/pf/html/pfappserver/root/
make vendor
make dev

log_section "Build captive portal"
cd /usr/local/pf/html/common
make vendor
make dev

log_section "Build Golang environment"
cd /usr/local/pf/go
make go-env
make all
make copy

log_section "Fix permissions and start unmanaged services"
cd /usr/local/pf
make permissions
systemctl start packetfence-mariadb
systemctl start packetfence-config packetfence-redis-cache
systemctl start rsyslog

log_section "Start all PF services"
/usr/local/pf/bin/pfcmd service pf restart
