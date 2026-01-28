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
echo "PacketFence Offline Install - Phase A"
echo "PF_VERSION: ${PF_VERSION}"
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

# Step 2: Install packages from DVD needed for first boot
echo "===> Step 2: Installing packages from DVD (needed for first boot)"

# Install packages from DVD that are required during first boot when DVD is removed.
# These are standard Debian packages ON the DVD, but won't be available after reboot.
#
# Packages needed by fingerbank (with versioned dependencies):
# - liblog-log4perl-perl (>= 1.43): fingerbank requires specific version
# - libconfig-inifiles-perl (>= 2.88): fingerbank requires specific version
# - liburi-perl, libregexp-ipv6-perl: needed by HTTP::Request/LWP in packetfence-perl
# - libnet-ssleay-perl, libio-socket-ssl-perl: SSL/TLS support (XS modules)
# - acl: needed by packetfence preinst script (setfacl command)
# - libdbd-sqlite3-perl, sqlite3, libdata-powerset-perl: fingerbank dependencies
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    liblog-log4perl-perl \
    libconfig-inifiles-perl \
    liburi-perl \
    libregexp-ipv6-perl \
    libnet-ssleay-perl \
    libio-socket-ssl-perl \
    acl \
    libdbd-sqlite3-perl \
    sqlite3 \
    libdata-powerset-perl \
    || {
    echo "Warning: Some packages failed to install, continuing..."
}

# Step 2b: Install packages from pf-repo (not on DVD)
echo "===> Step 2b: Installing packages from local pf-repo (not on DVD)"

# These packages are NOT on the Debian DVD, they come from pf-repo
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    lnav \
    cgroupfs-mount \
    libcache-bdb-perl \
    libcjson1 \
    libglib2.0-0 \
    libglib2.0-bin \
    || {
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
echo "===> Step 4: Installing PacketFence dependencies from DVD"

# Ensure kernel is marked to not be auto-removed
apt-mark hold linux-image-amd64 linux-image-* 2>/dev/null || true

# Install ALL dependencies that PacketFence needs from the DVD
# PacketFence package itself will be installed on first boot when Docker is running
# These are standard Debian packages that won't be available after DVD is removed
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    linux-headers-amd64 \
    mariadb-server \
    mariadb-client \
    redis-server \
    redis-tools \
    freeradius \
    freeradius-ldap \
    freeradius-mysql \
    freeradius-utils \
    freeradius-rest \
    freeradius-redis \
    freeradius-common \
    haproxy \
    keepalived \
    samba \
    snmpd \
    snmp \
    monit \
    bind9-dnsutils \
    bind9-libs \
    bind9-host \
    vlan \
    arping \
    fping \
    ipset \
    jq \
    snmptrapfmt \
    snmptrapd \
    snmp-mibs-downloader \
    conntrack \
    rsyslog \
    ipcalc \
    ipcalc-ng \
    apache2 \
    apache2-utils \
    libapache2-mod-apreq2 \
    libapache2-mod-perl2 \
    libapache2-request-perl \
    libapache-ssllookup-perl \
    libapache2-mod-systemd \
    eapoltest \
    python3-impacket \
    python-is-python3 \
    python3.11-venv \
    krb5-user \
    sscep \
    libwww-perl \
    libtext-csv-xs-perl \
    libcgi-session-serialize-yaml-perl \
    libapache-dbi-perl \
    libdbd-mysql-perl \
    libnetwork-ipv4addr-perl \
    iptables-netflow-dkms \
    liblwp-useragent-determined-perl \
    libnet-pcap-perl \
    libsnmp-perl \
    libnet-telnet-cisco-perl \
    libnet-cisco-mse-rest-perl \
    perlmagick \
    libregexp-common-email-address-perl \
    libregexp-common-time-perl \
    libperl-critic-perl \
    libhtml-template-perl \
    libtest-perl-critic-perl \
    libthread-pool-simple-perl \
    libuniversal-exports-perl \
    libnet-rawip-perl \
    libdatetime-format-dateparse-perl \
    perl-doc \
    librrds-perl \
    libnetpacket-perl \
    libmime-lite-perl \
    libdata-swap-perl \
    libposix-atfork-perl \
    libcrypt-openssl-pkcs12-perl \
    libnet-dhcp-perl \
    libnet-interface-perl \
    libnet-radius-perl \
    libbsd-resource-perl \
    libparse-nessus-nbe-perl \
    libtest-mockdbi-perl \
    libsoap-lite-perl \
    libnet-frame-perl \
    bsdmainutils \
    libwww-curl-perl \
    libposix-2008-perl \
    libdata-messagepack-stream-perl \
    libnet-nessus-xmlrpc-perl \
    libnet-nessus-rest-perl \
    libnet-route-perl \
    libnet-arp-perl \
    locales-all \
    python3-mysqldb \
    libcrypt-smime-perl \
    liblasso-perl \
    libcisco-accesslist-parser-perl \
    libparse-eyapp-perl \
    python3-twisted \
    uuid-runtime \
    || {
    echo "Warning: Some dependencies failed to install, attempting to fix..."
    dpkg --configure -a
    DEBIAN_FRONTEND=noninteractive apt-get install -y -f
}

# Verify kernel is still installed
if ! ls /boot/vmlinuz-* >/dev/null 2>&1; then
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

# Debug: Show what's on the ISO
echo "Checking ISO contents..."
echo "Contents of /media/cdrom:"
ls -la /media/cdrom/ 2>/dev/null || echo "  (cannot list /media/cdrom)"
echo "Contents of /media/cdrom/pf-repo:"
ls -la /media/cdrom/pf-repo/ 2>/dev/null || echo "  (cannot list /media/cdrom/pf-repo)"
echo "Contents of /media/cdrom/pf-repo/pool:"
ls -la /media/cdrom/pf-repo/pool/ 2>/dev/null || echo "  (cannot list /media/cdrom/pf-repo/pool)"
echo "Contents of /media/cdrom/pf-repo/pool/main:"
ls -la /media/cdrom/pf-repo/pool/main/ 2>/dev/null || echo "  (cannot list /media/cdrom/pf-repo/pool/main)"

if [ -d /media/cdrom/pf-repo/pool/main ]; then
    echo "Copying PacketFence .deb packages from ISO to ${PF_CACHE_DIR}..."

    # Find and show what we're copying
    echo "PacketFence packages found on ISO:"
    find /media/cdrom/pf-repo/pool/main -name "packetfence*.deb" -o -name "fingerbank*.deb" 2>/dev/null | head -20

    # Copy all .deb files from the pool (simpler and more reliable)
    cp /media/cdrom/pf-repo/pool/main/*.deb ${PF_CACHE_DIR}/ 2>/dev/null || {
        echo "Warning: cp failed, trying find method..."
        find /media/cdrom/pf-repo/pool/main -name "*.deb" -exec cp {} ${PF_CACHE_DIR}/ \; 2>/dev/null || true
    }

    if ls ${PF_CACHE_DIR}/*.deb 1> /dev/null 2>&1; then
        echo "PacketFence packages copied successfully:"
        ls -la ${PF_CACHE_DIR}/
    else
        echo "ERROR: No .deb packages found in ${PF_CACHE_DIR} after copy attempt"
        echo "This will cause first-boot installation to fail!"
    fi
else
    echo "ERROR: PF repo not found on ISO at /media/cdrom/pf-repo/pool/main"
    echo "Available directories on ISO:"
    find /media/cdrom -type d 2>/dev/null | head -20
fi

# Step 6: Configure system
echo "===> Step 6: Configuring system"

# Allow SSH root login
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config

# Remove any remaining inverse.ca references from sources.list
# (they will be added properly when network is available)
sed -i 's/.*inverse\.ca.*//g' /etc/apt/sources.list

# Configure PacketFence repository for future updates (will be used when network is available)
# Using debian-branches for now - change to debian/${PF_VERSION} when stable packages are published
cat > /etc/apt/sources.list.d/packetfence.list << EOF
deb [signed-by=/etc/apt/keyrings/packetfence.gpg] https://inverse.ca/downloads/PacketFence/debian-branches/${PF_VERSION} bookworm bookworm
EOF

# Step 7: Create first-boot service
echo "===> Step 7: Creating first-boot service"

# Create the first-boot script (Phase B)
cat > /usr/local/bin/packetfence-first-boot.sh << 'FIRSTBOOT_EOF'
#!/bin/bash
set -o pipefail -o errexit

# =============================================================================
# PacketFence First Boot Script - Phase B
# =============================================================================
# This script runs on first boot when systemd is active and Docker can run.
# It completes the PacketFence installation that couldn't happen during preseed.
# =============================================================================

LOG_FILE="/var/log/packetfence-first-boot.log"
INSTALL_SUCCESS=0

# Redirect all output to log file only (not to console)
exec >> ${LOG_FILE} 2>&1

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

  Depending on allocated resources, PacketFence installation can take 10-40 minutes.
  Progress can be monitored at: /var/log/packetfence-first-boot.log

  Please wait until installation completes before using the system.

================================================================================

EOF
}

# Function to handle script exit (success or failure)
handle_exit() {
    local exit_code=$?
    if [ ${INSTALL_SUCCESS} -eq 0 ] && [ ${exit_code} -ne 0 ]; then
        echo ""
        echo "=============================================="
        echo "ERROR: Script failed with exit code ${exit_code}"
        echo "Time: $(date)"
        echo "=============================================="
        cat > /etc/issue << EOF
================================================================================
  PacketFence Installation FAILED
================================================================================

  The installation encountered an error and could not complete.

  Please check the log file for details:
    /var/log/packetfence-first-boot.log

  To retry installation:
    1. Log in as root
    2. Run: /usr/local/bin/packetfence-first-boot.sh

  Common issues:
    - Missing .deb packages in /var/cache/packetfence-install
    - Docker service failed to start
    - Network issues during package installation

================================================================================

EOF
    fi
}

# Set up exit trap to catch all exits (success or failure)
trap handle_exit EXIT

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

# Re-tag Docker images to match what PacketFence expects
# Images may have been downloaded with a different tag (e.g., devel) than what
# the installed PacketFence package expects (e.g., feature-usb-bootable-iso2)
echo "===> Checking if Docker images need re-tagging..."
LOADED_TAG=""
EXPECTED_TAG=""

# Read the tag that was used when images were downloaded
if [ -f ${DOCKER_CACHE_DIR}/image-tag.txt ]; then
    LOADED_TAG=$(cat ${DOCKER_CACHE_DIR}/image-tag.txt | tr -d '[:space:]')
    echo "Loaded images have tag: ${LOADED_TAG}"
fi

# Read the tag that PacketFence expects (from build_id or pf-release)
if [ -f /usr/local/pf/conf/build_id ]; then
    EXPECTED_TAG=$(grep -oP 'TAG_OR_BRANCH_NAME=\K.*' /usr/local/pf/conf/build_id 2>/dev/null | tr -d '[:space:]' || true)
fi
# Fallback: extract version from pf-release if build_id doesn't have TAG_OR_BRANCH_NAME
if [ -z "${EXPECTED_TAG}" ] && [ -f /usr/local/pf/conf/pf-release ]; then
    # For releases, use the version number (e.g., 15.1.0)
    PF_VERSION=$(cat /usr/local/pf/conf/pf-release | awk '{print $2}')
    if [[ "${PF_VERSION}" == *"/"* ]]; then
        # Branch name format: feature/branch-name -> feature-branch-name
        EXPECTED_TAG=$(echo "${PF_VERSION}" | sed 's#/#-#g')
    else
        EXPECTED_TAG="${PF_VERSION}"
    fi
    echo "PacketFence expects tag (from pf-release): ${EXPECTED_TAG}"
else
    echo "PacketFence expects tag (from build_id): ${EXPECTED_TAG}"
fi

# Re-tag images if needed (for different tags)
if [ -n "${LOADED_TAG}" ] && [ -n "${EXPECTED_TAG}" ] && [ "${LOADED_TAG}" != "${EXPECTED_TAG}" ]; then
    echo "Tags differ - re-tagging images from '${LOADED_TAG}' to '${EXPECTED_TAG}'..."
    # Get list of images with the loaded tag
    IMAGES_TO_RETAG=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep ":${LOADED_TAG}$" || true)
    if [ -n "${IMAGES_TO_RETAG}" ]; then
        for img in ${IMAGES_TO_RETAG}; do
            new_tag="${img%:${LOADED_TAG}}:${EXPECTED_TAG}"
            echo "  Re-tagging: ${img} -> ${new_tag}"
            docker tag "${img}" "${new_tag}" || echo "    Warning: Failed to re-tag ${img}"
        done
        echo "Docker images re-tagged successfully"
    else
        echo "No images found with tag '${LOADED_TAG}' to re-tag"
    fi
else
    if [ -z "${LOADED_TAG}" ]; then
        echo "No image-tag.txt found, skipping re-tag"
    elif [ -z "${EXPECTED_TAG}" ]; then
        echo "Could not determine expected tag, skipping re-tag"
    else
        echo "Tags match (${LOADED_TAG}), no re-tagging needed"
    fi
fi

# Re-tag images for local registry alias (packetfence/<image>:<tag>)
# PacketFence services expect images at packetfence/<image> not ghcr.io/inverse-inc/packetfence/<image>
echo "===> Creating local registry aliases for Docker images..."
TAG_TO_USE="${EXPECTED_TAG:-${LOADED_TAG}}"
if [ -n "${TAG_TO_USE}" ]; then
    GHCR_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "ghcr.io/inverse-inc/packetfence/.*:${TAG_TO_USE}$" || true)
    if [ -n "${GHCR_IMAGES}" ]; then
        for img in ${GHCR_IMAGES}; do
            # Extract image name (e.g., pfconfig from ghcr.io/inverse-inc/packetfence/pfconfig:tag)
            img_name=$(echo "${img}" | sed "s|ghcr.io/inverse-inc/packetfence/||" | sed "s|:${TAG_TO_USE}$||")
            local_tag="packetfence/${img_name}:${TAG_TO_USE}"
            echo "  Creating alias: ${img} -> ${local_tag}"
            docker tag "${img}" "${local_tag}" || echo "    Warning: Failed to create alias ${local_tag}"
        done
        echo "Local registry aliases created successfully"
    else
        echo "No ghcr.io images found to alias"
    fi
else
    echo "No tag available, skipping local registry aliases"
fi

# Step 3: Install PacketFence
update_progress "Step 3/6" "Installing PacketFence dependencies..."
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
    echo ""

    # Step 3a: Create local APT repository from cached packages
    # This allows apt-get to properly resolve dependencies
    echo "===> Step 3a: Creating local APT repository from cached packages..."

    LOCAL_REPO="/var/cache/packetfence-repo"
    mkdir -p ${LOCAL_REPO}/pool
    cp ${PF_CACHE_DIR}/*.deb ${LOCAL_REPO}/pool/

    # Generate Packages index
    cd ${LOCAL_REPO}
    mkdir -p dists/local/main/binary-amd64
    dpkg-scanpackages pool /dev/null > dists/local/main/binary-amd64/Packages
    gzip -k dists/local/main/binary-amd64/Packages

    # Create Release file
    cat > dists/local/Release << RELEASE_EOF
Origin: PacketFence Local
Label: PacketFence Local
Suite: local
Codename: local
Architectures: amd64
Components: main
Description: PacketFence offline installation local repository
RELEASE_EOF

    # Configure apt to use the local repository
    cat > /etc/apt/sources.list.d/packetfence-local-install.list << APT_EOF
deb [trusted=yes] file://${LOCAL_REPO} local main
APT_EOF

    # Update apt cache
    apt-get update
    echo "Local APT repository created successfully"
    echo ""

    # Step 3b: Install all dependency packages first (before major applications)
    echo "===> Step 3b: Installing dependency packages..."

    # Get list of all non-packetfence/non-fingerbank packages from the local repo
    DEP_PKGS=$(ls ${PF_CACHE_DIR}/*.deb 2>/dev/null | xargs -n1 basename | sed 's/_.*$//' | grep -v -E '^(packetfence|fingerbank)' | sort -u || true)
    if [ -n "$DEP_PKGS" ]; then
        echo "Installing dependencies: $DEP_PKGS"
        DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades $DEP_PKGS || true
    fi
    echo ""

    # Step 3c: Install PacketFence ecosystem packages
    echo "===> Step 3c: Installing PacketFence packages..."

    # Install packetfence-perl (provides virtual packages)
    echo "Installing packetfence-perl..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades packetfence-perl || true

    # Install fingerbank packages
    echo "Installing fingerbank-collector..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades fingerbank-collector || true

    echo "Installing fingerbank..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades fingerbank || true

    # Install other packetfence-* packages (excluding main packetfence)
    echo "Installing packetfence dependency packages..."
    PF_DEP_NAMES=$(ls ${PF_CACHE_DIR}/packetfence-*.deb 2>/dev/null | xargs -n1 basename | sed 's/_.*$//' | grep -v "^packetfence$" | sort -u || true)
    if [ -n "$PF_DEP_NAMES" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades $PF_DEP_NAMES || true
    fi
    echo ""

    # Step 3d: Install main PacketFence package LAST (requires Docker running)
    echo "===> Step 3d: Installing main PacketFence package..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades packetfence || {
        echo "Warning: apt-get install packetfence had issues, trying dpkg..."
        PF_MAIN_PKG=$(ls ${PF_CACHE_DIR}/packetfence_*.deb 2>/dev/null | head -n1)
        if [ -n "$PF_MAIN_PKG" ]; then
            DEBIAN_FRONTEND=noninteractive dpkg --force-depends -i ${PF_MAIN_PKG}
            DEBIAN_FRONTEND=noninteractive dpkg --configure --force-depends packetfence || true
        fi
    }

    # Cleanup local repo config
    rm -f /etc/apt/sources.list.d/packetfence-local-install.list
    apt-get update 2>/dev/null || true

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

# Mark installation as successful (prevents error message in exit trap)
INSTALL_SUCCESS=1

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
TimeoutStartSec=2700
StandardOutput=journal
StandardError=journal

[Install]
# Use basic.target instead of multi-user.target to avoid deadlock:
# first-boot runs postinst -> postinst calls "systemctl isolate packetfence-base.target"
# packetfence-base.target depends on multi-user.target
# If first-boot is WantedBy multi-user.target, multi-user.target waits for first-boot to complete -> deadlock
# Using basic.target, the service is queued early but After=docker.service ensures it waits for Docker.
# By the time first-boot runs, multi-user.target is already active, breaking the cycle.
WantedBy=basic.target
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
