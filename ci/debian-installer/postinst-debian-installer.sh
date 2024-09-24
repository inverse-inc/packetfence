#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_VERSION=${1:-}

apt install packetfence -y
sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/.*inverse\.ca.*//g' /etc/apt/sources.list
apt-get update
apt install gnupg sudo curl
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor -o /etc/apt/keyrings/packetfence.gpg
echo "deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/14.0 bookworm bookworm" > \
	/etc/apt/sources.list.d/packetfence.list
echo "SET PASSWORD FOR root@'localhost' = PASSWORD('');" > /tmp/reset-root.sql
mkdir /run/mysqld
chown mysql: /run/mysqld/
timeout 10 mysqld --skip-networking --init-file /tmp/reset-root.sql --user=mysql > /var/reset-root.log 2>&1
rm -f /tmp/reset-root.sql
pkill -e docker
