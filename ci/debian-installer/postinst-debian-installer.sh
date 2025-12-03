#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_VERSION=${1:-}

sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd.service
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor -o /etc/apt/keyrings/packetfence.gpg
echo "deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bookworm bookworm" > \
	/etc/apt/sources.list.d/packetfence.list
echo "SET PASSWORD FOR root@'localhost' = PASSWORD('');" > /tmp/reset-root.sql
apt-get update
apt-get install packetfence -y
# Reset MariaDB root password to empty for PacketFence
# This is required because the ISO installer environment skips this in the package postinst
mkdir -p /run/mysqld
chown mysql: /run/mysqld/
mysqld --skip-networking --init-file /tmp/reset-root.sql --user=mysql > /var/reset-root.log 2>&1 &
MYSQLD_PID=$!
# Wait for mysqld to finish processing init-file (max 10 seconds)
TIMEOUT=10
INTERVAL=0.5
ELAPSED=0
while kill -0 $MYSQLD_PID 2>/dev/null && (( $(echo "$ELAPSED < $TIMEOUT" | bc) )); do
    sleep $INTERVAL
    ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc)
done
# Shutdown mysqld gracefully if still running
kill $MYSQLD_PID 2>/dev/null || true
wait $MYSQLD_PID 2>/dev/null || true
rm -f /tmp/reset-root.sql

# Detect primary non-loopback IPv4 address
VM_IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)

# Add custom message to display before login prompt
cat > /etc/issue <<EOF

================================================================================
  This VM has been installed with PacketFence net install ISO

  - SSH root access by password has been granted
  - You can find the admin GUI on https://${VM_IP}:1443/

  To update or delete this message, edit or remove /etc/issue
================================================================================

EOF

# Also add to /etc/issue.net for SSH sessions
cat > /etc/issue.net << 'EOF'

================================================================================
  This VM has been installed with PacketFence net install ISO

  - SSH root access by password has been granted
  - You can find the admin GUI on https://VM_IP:1443/

  To update or delete this message, edit or remove /etc/issue.net
================================================================================

EOF
