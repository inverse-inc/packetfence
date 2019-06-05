#!/bin/bash

echo "Create all necessary files..."

cd /usr/local/pf
make devel
make conf/ssl/server.pem
mkdir /usr/local/pf/var/ssl_mutex
cp ../pf-pkg/conf/pf.conf conf/
cp ../pf-pkg/conf/pfconfig.conf conf/
cp ../pf-pkg/conf/currently-at conf/
ln -s /usr/local/pf/raddb/sites-available/status /usr/local/pf/raddb/sites-enabled/status


echo "Build web admin..."
cd /usr/local/pf/html/pfappserver/root/static.alt/
sudo make vendor
sudo make dev

echo "Build captive portal..."
cd /usr/local/pf/html/common
sudo make vendor
sudo make dev

echo "Build Golang environment..."
cd /usr/local/pf/go
make go-env
/usr/local/pf/addons/packages/build-go.sh build /usr/local/pf /usr/local/pf/sbin/

echo "Fix permissions and start services..."
cd /usr/local/pf
make permissions
systemctl start packetfence-mariadb
systemctl start packetfence-config packetfence-redis-cache

echo "Start all PF services..."
/usr/local/pf/bin/pfcmd service pf restart
