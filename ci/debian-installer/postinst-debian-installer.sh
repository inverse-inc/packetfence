#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_VERSION=${1:-}

sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd.service
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor -o /etc/apt/keyrings/packetfence.gpg
echo "deb [signed-by=/etc/apt/keyrings/packetfence.gpg] https://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bookworm bookworm" > \
	/etc/apt/sources.list.d/packetfence.list
echo "SET PASSWORD FOR root@'localhost' = PASSWORD('');" > /tmp/reset-root.sql
apt-get update
apt install packetfence -y
mkdir /run/mysqld
chown mysql: /run/mysqld/
timeout 10 mysqld --skip-networking --init-file /tmp/reset-root.sql --user=mysql > /var/reset-root.log 2>&1
rm -f /tmp/reset-root.sql
#pkill -e docker
