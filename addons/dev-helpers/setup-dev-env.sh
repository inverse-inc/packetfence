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
  echo "Currently, the nodejs version that should be used is 20.x which can be installed using: \`dnf module install nodejs:20\`"
  exit 1
fi

log_section "Cleanup previous dev setup directories"
rm -fr /usr/local/go
rm -fr /usr/local/pf-pkg

log_section "Stop services"
systemctl isolate multi-user

log_section "Replace /usr/local/pf by git repository"
mv /usr/local/pf /usr/local/pf-pkg
git clone https://github.com/inverse-inc/packetfence /usr/local/pf

log_section "Set the safe.directory in git"
git config --global --add safe.directory /usr/local/pf

log_section "install required header files from PF repo"
dnf install -y --enablerepo=packetfence libcurl-devel cjson-devel

cd /usr/local/pf/

BRANCH=${BRANCH:-devel}
git checkout $BRANCH

log_section "Create all necessary files"

# to have all Perl dependencies at correct location
cp -r /usr/local/pf-pkg/lib_perl /usr/local/pf/

cd /usr/local/pf
make devel
make conf/ssl/server.pem
mkdir -p /usr/local/pf/var/ssl_mutex
mkdir -p /usr/local/pf/logs
mkdir -p /usr/local/pf/conf/ssl/acme-challenge
# to keep settings set up during configurator
cp /usr/local/pf-pkg/conf/pf.conf conf/
cp /usr/local/pf-pkg/conf/pfconfig.conf conf/
cp /usr/local/pf-pkg/conf/networks.conf conf/
# to keep iptables rule for vagrant management
cp /usr/local/pf-pkg/conf/iptables.conf conf/

log_section "Build web admin"
cd /usr/local/pf/html/pfappserver/root/
make vendor
npm run build-debug

log_section "Build captive portal"
cd /usr/local/pf/html/common
make vendor
make dev

log_section "Build Golang environment"
cd /usr/local/pf/go
make go-env
make all
make copy

log_section "Setup container files"
cd /usr/local/pf
TAG_OR_BRANCH_NAME=`git rev-parse --abbrev-ref HEAD | sed 's#[/|.]#-#g'`
echo -n TAG_OR_BRANCH_NAME=$TAG_OR_BRANCH_NAME > conf/build_id
echo LOCAL_DEV=true > containers/.local_env

for img in pfbuild-debian-bookworm pfdebian radiusd; do
  docker pull ghcr.io/inverse-inc/packetfence/$img:$TAG_OR_BRANCH_NAME
  docker tag ghcr.io/inverse-inc/packetfence/$img:$TAG_OR_BRANCH_NAME packetfence/$img:$TAG_OR_BRANCH_NAME
done

log_section "Fix permissions and start unmanaged services"
cd /usr/local/pf
make permissions
systemctl start packetfence-config packetfence-redis-cache
while ! /usr/local/pf/bin/pfcmd pfconfig get resource::fqdn 2>&1| grep last_touch_cache > /dev/null ; do
        echo "Waiting for pfconfig to be online..."
done
echo "pfconfig is now online!"
systemctl start packetfence-mariadb
systemctl restart rsyslog

log_section "Start all PF services"
/usr/local/pf/bin/pfcmd service pf restart
