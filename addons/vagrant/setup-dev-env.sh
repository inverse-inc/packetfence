#!/bin/bash

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

log_section "Create all necessary files"
cd /usr/local/pf
make devel
make conf/ssl/server.pem > /dev/null
mkdir /usr/local/pf/var/ssl_mutex
cp ../pf-pkg/conf/pf.conf conf/
cp ../pf-pkg/conf/pfconfig.conf conf/
make conf/currently-at

log_section "Untracked some file before generation"
cat >> .git/info/exclude <<EOF
html/common/styles.css
html/common/styles.css.map
html/pfappserver/root/static.alt/package-lock.json
EOF

log_section "Build web admin"
cd /usr/local/pf/html/pfappserver/root/static.alt/
sudo make vendor
sudo make dev

log_section "Build captive portal"
cd /usr/local/pf/html/common
sudo make vendor
sudo make dev

log_section "Build Golang environment"
cd /usr/local/pf/go
make go-env
/usr/local/pf/addons/packages/build-go.sh build /usr/local/pf /usr/local/pf/sbin/

log_section "Fix permissions and start unmanaged services"
cd /usr/local/pf
make permissions
systemctl start packetfence-mariadb
systemctl start packetfence-config packetfence-redis-cache
systemctl start rsyslog

log_section "Start all PF services"
/usr/local/pf/bin/pfcmd service pf restart
