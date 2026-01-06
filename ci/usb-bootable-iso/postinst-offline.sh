#!/bin/bash
set -o nounset -o pipefail -o errexit

# =============================================================================
# PacketFence Offline Post-Installation Script - Phase A (runs during preseed)
# =============================================================================
# IMPORTANT: This script runs in a chroot environment during Debian installer.
# systemd is NOT running, so Docker/systemctl commands will NOT work here.
# PacketFence installation is deferred to first boot (Phase B).
# =============================================================================

PF_VERSION=${1:-15.1}

echo "=============================================="
echo "PacketFence Offline Post-Installation Script"
echo "Phase A: Installing dependencies (preseed)"
echo "=============================================="
echo "PF_VERSION: ${PF_VERSION}"
echo "=============================================="
echo "NOTE: DVD ISO is mounted at /media/cdrom"
echo "      DVD provides all Debian packages"
echo "      PF repo at /media/cdrom/pf-repo"
echo ""
echo "IMPORTANT: PacketFence will be installed on"
echo "           first boot (Docker required)"
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

# Step 3: Install Docker packages
echo "===> Step 3: Installing Docker packages"

# Install Docker packages from local repo
# NOTE: Do NOT attempt to start Docker - it won't work in chroot environment
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io || {
    echo "Warning: Docker packages installation had issues, attempting to fix..."
    dpkg --configure -a
    DEBIAN_FRONTEND=noninteractive apt-get install -y -f
}

# Step 4: Install PacketFence dependencies (but NOT PacketFence itself)
echo "===> Step 4: Installing PacketFence dependencies"

# Ensure kernel is marked to not be auto-removed
apt-mark hold linux-image-amd64 linux-image-* 2>/dev/null || true

# Install key dependencies that PacketFence needs
# PacketFence package itself will be installed on first boot when Docker is running
# Include linux-image-amd64 to ensure kernel is not removed by dependency resolution
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    mariadb-server \
    redis-server \
    freeradius \
    freeradius-ldap \
    freeradius-mysql \
    freeradius-utils \
    freeradius-rest \
    freeradius-redis \
    haproxy \
    keepalived \
    samba \
    snmpd \
    monit \
    fingerbank-collector \
    || {
    echo "Warning: Some dependencies failed to install, attempting to fix..."
    dpkg --configure -a
    DEBIAN_FRONTEND=noninteractive apt-get install -y -f
}

# Verify kernel is still installed
if [ ! -f /boot/vmlinuz-* ]; then
    echo "ERROR: Kernel missing! Reinstalling..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y linux-image-amd64
fi

# Step 5: Copy Docker images to target filesystem
echo "===> Step 5: Copying Docker images to target filesystem"

DOCKER_CACHE_DIR="/var/cache/packetfence-docker-images"
mkdir -p ${DOCKER_CACHE_DIR}

if [ -d /media/cdrom/docker-images ]; then
    echo "Copying Docker images from ISO to ${DOCKER_CACHE_DIR}..."
    cp -r /media/cdrom/docker-images/* ${DOCKER_CACHE_DIR}/ || {
        echo "Warning: Failed to copy some Docker images"
    }
    echo "Docker images copied successfully"
    ls -la ${DOCKER_CACHE_DIR}/
else
    echo "Warning: Docker images not found on ISO at /media/cdrom/docker-images"
fi

# Step 5b: Copy PacketFence .deb packages for installation on first boot
echo "===> Step 5b: Copying PacketFence .deb packages to target filesystem"

PF_CACHE_DIR="/var/cache/packetfence-install"
mkdir -p ${PF_CACHE_DIR}

if [ -d /media/cdrom/pf-repo/pool/main ]; then
    echo "Copying PacketFence .deb packages from ISO to ${PF_CACHE_DIR}..."
    # Copy all PacketFence-related packages (main + pre-depends + depends)
    find /media/cdrom/pf-repo/pool/main -name "packetfence*.deb" -exec cp {} ${PF_CACHE_DIR}/ \; || {
        echo "Warning: Failed to copy some PacketFence .deb packages"
    }
    # Also copy fingerbank packages (pre-depends)
    find /media/cdrom/pf-repo/pool/main -name "fingerbank*.deb" -exec cp {} ${PF_CACHE_DIR}/ \; || {
        echo "Warning: Failed to copy fingerbank .deb packages"
    }
    if ls ${PF_CACHE_DIR}/*.deb 1> /dev/null 2>&1; then
        echo "PacketFence packages copied successfully:"
        ls -la ${PF_CACHE_DIR}/
    else
        echo "ERROR: No PacketFence .deb packages found"
    fi
else
    echo "Warning: PF repo not found on ISO at /media/cdrom/pf-repo/pool/main"
fi

# Step 6: Configure system
echo "===> Step 6: Configuring system"

# Allow SSH root login
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config

# Remove any remaining inverse.ca references from sources.list
# (they will be added properly when network is available)
sed -i 's/.*inverse\.ca.*//g' /etc/apt/sources.list

# Configure PacketFence repository for future updates (will be used when network is available)
cat > /etc/apt/sources.list.d/packetfence.list << EOF
deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bookworm bookworm
EOF

# Step 7: Create first-boot service
echo "===> Step 7: Creating first-boot service"

# Create the first-boot script (Phase B)
cat > /usr/local/bin/packetfence-first-boot.sh << 'FIRSTBOOT_EOF'
#!/bin/bash
set -o pipefail

# =============================================================================
# PacketFence First Boot Script - Phase B
# =============================================================================
# This script runs on first boot when systemd is active and Docker can run.
# It completes the PacketFence installation that couldn't happen during preseed.
# =============================================================================

LOG_FILE="/var/log/packetfence-first-boot.log"
exec > >(tee -a ${LOG_FILE}) 2>&1

# Function to update installation progress on login screen
update_progress() {
    local step="$1"
    local message="$2"
    cat > /etc/issue << EOF
================================================================================
  PacketFence Installation In Progress - Please Wait
================================================================================

  Current Step: ${step}
  Status: ${message}

  This process may take 10-15 minutes total.
  Progress can be monitored at: /var/log/packetfence-first-boot.log

  Please wait until installation completes before using the system.

================================================================================

EOF
}

# Display initial installation progress message on login screen
update_progress "Initializing" "Starting PacketFence installation..."

echo "=============================================="
echo "PacketFence First Boot - Phase B"
echo "Starting at: $(date)"
echo "=============================================="

DOCKER_CACHE_DIR="/var/cache/packetfence-docker-images"
PF_CACHE_DIR="/var/cache/packetfence-install"

# Step 1: Start Docker service
update_progress "Step 1/6" "Starting Docker service..."
echo "===> Step 1: Starting Docker service"
systemctl start docker || {
    echo "ERROR: Failed to start Docker service"
    exit 1
}

# Wait for Docker socket to be available
echo "Waiting for Docker to be ready..."
for i in {1..60}; do
    if [ -S /var/run/docker.sock ]; then
        echo "Docker is ready after ${i} seconds"
        break
    fi
    sleep 1
done

if [ ! -S /var/run/docker.sock ]; then
    echo "ERROR: Docker socket not available after 60 seconds"
    exit 1
fi

# Step 2: Load Docker images
update_progress "Step 2/6" "Loading Docker images (this may take several minutes)..."
echo "===> Step 2: Loading Docker images"

if [ -d ${DOCKER_CACHE_DIR} ] && [ -f ${DOCKER_CACHE_DIR}/load-images.sh ]; then
    chmod +x ${DOCKER_CACHE_DIR}/load-images.sh
    ${DOCKER_CACHE_DIR}/load-images.sh || {
        echo "Warning: Some Docker images failed to load"
    }
else
    echo "Warning: Docker images not found at ${DOCKER_CACHE_DIR}"
fi

# Step 3: Install PacketFence
update_progress "Step 3/6" "Installing PacketFence packages..."
echo "===> Step 3: Installing PacketFence"

# Remove local ISO repository configuration (ISO is no longer mounted)
echo "Removing local ISO repository configuration..."
rm -f /etc/apt/sources.list.d/packetfence-local.list
apt-get update 2>/dev/null || true

# Install PacketFence and all related packages from the copied .deb files
# Now that Docker is running, PacketFence postinst can configure containers
if ls ${PF_CACHE_DIR}/*.deb 1> /dev/null 2>&1; then
    echo "Installing PacketFence and related packages from cached .deb files..."
    echo "Packages to install:"
    ls ${PF_CACHE_DIR}/*.deb

    # Install all .deb files at once - dpkg will handle the dependency order
    DEBIAN_FRONTEND=noninteractive dpkg -i ${PF_CACHE_DIR}/*.deb || {
        echo "Warning: PacketFence installation had issues, fixing dependencies..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y -f
        DEBIAN_FRONTEND=noninteractive dpkg -i ${PF_CACHE_DIR}/*.deb
    }
    echo "PacketFence installation completed successfully"
else
    echo "ERROR: No PacketFence .deb packages found in ${PF_CACHE_DIR}"
    exit 1
fi

# Step 4: Reset MariaDB root password
update_progress "Step 4/6" "Configuring MariaDB database..."
echo "===> Step 4: Resetting MariaDB root password"

systemctl start mariadb || true
sleep 3

echo "SET PASSWORD FOR root@'localhost' = PASSWORD('');" > /tmp/reset-root.sql
mysql < /tmp/reset-root.sql 2>/dev/null || {
    # If mysql client fails, try with mysqld directly
    systemctl stop mariadb || true
    mkdir -p /run/mysqld
    chown mysql: /run/mysqld/
    timeout 30 mysqld --skip-networking --init-file=/tmp/reset-root.sql --user=mysql > /var/log/reset-root.log 2>&1 || true
}
rm -f /tmp/reset-root.sql

# Step 5: Cleanup
update_progress "Step 5/6" "Cleaning up temporary files..."
echo "===> Step 5: Cleanup"

# Remove Docker image cache
if [ -d ${DOCKER_CACHE_DIR} ]; then
    echo "Removing Docker image cache..."
    rm -rf ${DOCKER_CACHE_DIR}
fi

# Remove PacketFence .deb cache
if [ -d ${PF_CACHE_DIR} ]; then
    echo "Removing PacketFence installation cache..."
    rm -rf ${PF_CACHE_DIR}
fi

# Update package lists (if network available)
apt-get update 2>/dev/null || true

# Step 6: Start services
update_progress "Step 6/6" "Starting services and finalizing installation..."
echo "===> Step 6: Starting services"

systemctl start mariadb || true
systemctl start redis-server || true

# Update login screen with completion message
cat > /etc/issue << 'EOF'
================================================================================
  PacketFence Installation Complete!
================================================================================

  PacketFence has been successfully installed and configured.

  Next steps:
    1. Log in as root
    2. Run: /usr/local/pf/bin/pfcmd configreload hard
    3. Access the web interface at https://<this-ip>:1443

  For more information, see: /var/log/packetfence-first-boot.log

================================================================================

EOF

# Also add to MOTD for after login
cat > /etc/motd << 'EOF'
================================================================================
  Welcome to PacketFence!
================================================================================

  PacketFence has been successfully installed.

  Next steps:
    1. Run: /usr/local/pf/bin/pfcmd configreload hard
    2. Access the web interface at https://<this-ip>:1443

  Installation log: /var/log/packetfence-first-boot.log
  Documentation: https://packetfence.org/doc/

================================================================================
EOF

# Remove this script and service
echo "===> Removing first-boot service"
SCRIPT_PATH=$(readlink -f "$0")
rm -f /etc/systemd/system/packetfence-first-boot.service
systemctl daemon-reload
rm -f "$SCRIPT_PATH"

echo "=============================================="
echo "PacketFence First Boot Complete!"
echo "Finished at: $(date)"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Log in as root"
echo "2. Run: /usr/local/pf/bin/pfcmd configreload hard"
echo "3. Access the web interface at https://<ip>:1443"
echo "=============================================="
FIRSTBOOT_EOF

chmod +x /usr/local/bin/packetfence-first-boot.sh

# Create systemd service for first-boot
cat > /etc/systemd/system/packetfence-first-boot.service << 'SERVICE_EOF'
[Unit]
Description=PacketFence First Boot - Install PacketFence and Configure Containers
After=network.target docker.service mariadb.service
Wants=docker.service
ConditionPathExists=/usr/local/bin/packetfence-first-boot.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/packetfence-first-boot.sh
RemainAfterExit=yes
TimeoutStartSec=900
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl enable packetfence-first-boot.service

# Step 8: Display completion message
echo "=============================================="
echo "Phase A Complete - Dependencies Installed"
echo "=============================================="
echo ""
echo "IMPORTANT: PacketFence will be installed"
echo "automatically on first boot."
echo ""
echo "Please REMOVE the USB/ISO device before"
echo "the system reboots."
echo ""
echo "First boot will take several minutes to:"
echo "  - Start Docker service"
echo "  - Load container images"
echo "  - Install PacketFence"
echo "  - Configure services"
echo ""
echo "After first boot completes:"
echo "  1. Log in as root"
echo "  2. Run: /usr/local/pf/bin/pfcmd configreload hard"
echo "  3. Access: https://<ip>:1443"
echo "=============================================="
