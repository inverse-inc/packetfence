#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_VERSION=${1:-15.1}

echo "=============================================="
echo "PacketFence Offline Post-Installation Script"
echo "=============================================="
echo "PF_VERSION: ${PF_VERSION}"
echo "=============================================="
echo "NOTE: DVD ISO is mounted at /media/cdrom"
echo "      DVD provides all Debian packages"
echo "      PF repo at /media/cdrom/pf-repo"
echo "=============================================="

# Step 1: Configure local repository from ISO
echo "===> Step 1: Configuring local APT repository from ISO"

# Create directory for local repo
mkdir -p /etc/apt/keyrings

# Add PacketFence GPG key if available on ISO
if [ -f /media/cdrom/pf-repo/packetfence.gpg ]; then
    cp /media/cdrom/pf-repo/packetfence.gpg /etc/apt/keyrings/
fi

# Configure local repository from ISO
cat > /etc/apt/sources.list.d/packetfence-local.list << EOF
deb [trusted=yes] file:///media/cdrom/pf-repo bookworm main
EOF

# Disable CD-ROM apt source (prevents "Please insert CD" prompts)
sed -i '/^deb cdrom:/d' /etc/apt/sources.list

# Update package lists
apt-get update

# Step 2: Install packages not available on DVD-1
echo "===> Step 2: Installing packages from local repository (not on DVD-1)"

# Install lnav and cgroupfs-mount (not on DVD-1, must come from local repo)
DEBIAN_FRONTEND=noninteractive apt-get install -y lnav cgroupfs-mount || {
    echo "Warning: Some packages failed to install, continuing..."
}

# Step 3: Start Docker (required BEFORE PacketFence installation)
echo "===> Step 3: Starting Docker service"

# Start Docker service - PacketFence postinst needs it running
systemctl start docker || {
    echo "Warning: Failed to start Docker, attempting manual start..."
    dockerd &
    sleep 5
}

# Wait for Docker socket to be available
echo "Waiting for Docker to be ready..."
for i in {1..30}; do
    if [ -S /var/run/docker.sock ]; then
        echo "Docker is ready"
        break
    fi
    sleep 1
done

if [ ! -S /var/run/docker.sock ]; then
    echo "ERROR: Docker socket not available after 30 seconds"
fi

# Step 4: Load pre-downloaded Docker images
echo "===> Step 4: Loading Docker images"

if [ -d /media/cdrom/docker-images ] && [ -f /media/cdrom/docker-images/load-images.sh ]; then
    /media/cdrom/docker-images/load-images.sh || {
        echo "Warning: Some Docker images failed to load"
    }
else
    echo "Warning: Docker images not found on ISO"
fi

# Step 5: Install PacketFence from local repository
echo "===> Step 5: Installing PacketFence"

# Install PacketFence (this will also install dependencies from local repo)
# Docker is now running so postinst scripts can configure containers
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends packetfence || {
    echo "Warning: PacketFence installation had issues, attempting to fix..."
    dpkg --configure -a
    DEBIAN_FRONTEND=noninteractive apt-get install -y -f
}

# Step 6: Configure system
echo "===> Step 6: Configuring system"

# Allow SSH root login
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config

# Remove any remaining inverse.ca references from sources.list
# (they will be added properly when network is available)
sed -i 's/.*inverse\.ca.*//g' /etc/apt/sources.list

# Step 7: Configure PacketFence repository for future updates
echo "===> Step 7: Setting up PacketFence repository for future updates"

# Add PacketFence GPG key
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY 2>/dev/null | gpg --dearmor -o /etc/apt/keyrings/packetfence.gpg || {
    echo "Warning: Could not download GPG key (no network). Repository will be configured on first network access."
}

# Configure PacketFence repository (will be used when network is available)
cat > /etc/apt/sources.list.d/packetfence.list << EOF
deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bookworm bookworm
EOF

# Step 8: Reset MariaDB root password
echo "===> Step 8: Resetting MariaDB root password"

echo "SET PASSWORD FOR root@'localhost' = PASSWORD('');" > /tmp/reset-root.sql
mkdir -p /run/mysqld
chown mysql: /run/mysqld/
timeout 30 mysqld --skip-networking --init-file /tmp/reset-root.sql --user=mysql > /var/log/reset-root.log 2>&1 || true
rm -f /tmp/reset-root.sql

# Step 9: Stop services that shouldn't run during installation
echo "===> Step 9: Stopping services"

# Stop Docker (will be started on first boot)
pkill -e docker 2>/dev/null || true
systemctl stop docker 2>/dev/null || true

# Stop MariaDB
systemctl stop mariadb 2>/dev/null || true

# Step 10: Create first-boot marker
echo "===> Step 10: Creating first-boot configuration"

# Create a first-boot script to finalize setup
cat > /usr/local/bin/packetfence-first-boot.sh << 'FIRSTBOOT_EOF'
#!/bin/bash
# PacketFence first-boot configuration script

# Remove this script after execution
SCRIPT_PATH=$(readlink -f "$0")

echo "PacketFence first-boot configuration..."

# Start required services
systemctl start docker
systemctl start mariadb
systemctl start redis-server

# Remove the local ISO repository configuration
rm -f /etc/apt/sources.list.d/packetfence-local.list

# Update package lists (if network available)
apt-get update 2>/dev/null || true

# Remove this script
rm -f "$SCRIPT_PATH"
rm -f /etc/systemd/system/packetfence-first-boot.service
systemctl daemon-reload

echo "First-boot configuration complete!"
FIRSTBOOT_EOF
chmod +x /usr/local/bin/packetfence-first-boot.sh

# Create systemd service for first-boot
cat > /etc/systemd/system/packetfence-first-boot.service << 'SERVICE_EOF'
[Unit]
Description=PacketFence First Boot Configuration
After=network.target docker.service
ConditionPathExists=/usr/local/bin/packetfence-first-boot.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/packetfence-first-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl enable packetfence-first-boot.service

echo "=============================================="
echo "PacketFence Offline Installation Complete!"
echo "=============================================="
echo "The system will reboot. After reboot:"
echo "1. Log in as root"
echo "2. Run: /usr/local/pf/bin/pfcmd configreload hard"
echo "3. Access the web interface at https://<ip>:1443"
echo "=============================================="
