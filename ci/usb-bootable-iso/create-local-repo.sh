#!/bin/bash
set -o nounset -o pipefail -o errexit

# Ensure /usr/sbin is in PATH (debootstrap is installed there)
export PATH="/usr/sbin:/sbin:${PATH}"

# Arguments
REPO_DIR=${1:-./repo}
PF_RELEASE_VERSION=${2:-15.1}

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

echo "=============================================="
echo "Creating PacketFence Package Repository"
echo "(Will be appended to DVD repo on ISO)"
echo "=============================================="
echo "REPO_DIR: ${REPO_DIR}"
echo "PF_RELEASE_VERSION: ${PF_RELEASE_VERSION}"
echo "=============================================="

# Use absolute path for REPO_DIR
REPO_DIR=$(cd "$(dirname "${REPO_DIR}")" && pwd)/$(basename "${REPO_DIR}")

# Create directory structure for PacketFence packages
mkdir -p ${REPO_DIR}/pool/main
mkdir -p ${REPO_DIR}/dists/bookworm/main/binary-amd64

# Create a temporary chroot for package download
CHROOT_DIR=$(mktemp -d)
trap "echo 'Cleaning up chroot...'; sudo rm -rf ${CHROOT_DIR}" EXIT

echo "===> Creating minimal chroot for package download"
sudo debootstrap --variant=minbase --include=apt,gnupg,ca-certificates bookworm ${CHROOT_DIR} http://deb.debian.org/debian

# Add PacketFence repository only (we'll use DVD for Debian packages)
echo "===> Configuring PacketFence repository in chroot"
sudo mkdir -p ${CHROOT_DIR}/etc/apt/keyrings
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor | sudo tee ${CHROOT_DIR}/etc/apt/keyrings/packetfence.gpg > /dev/null
sudo tee ${CHROOT_DIR}/etc/apt/sources.list.d/packetfence.list > /dev/null << EOF
deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/${PF_RELEASE_VERSION} bookworm bookworm
EOF

# Copy GPG key to repo for later use
sudo cp ${CHROOT_DIR}/etc/apt/keyrings/packetfence.gpg ${REPO_DIR}/packetfence.gpg

# List of PacketFence-specific packages to download
# Note: DVD already has all standard Debian packages (systemd, mariadb, etc.)
# We need to download what's NOT on the DVD:
#   - PacketFence and fingerbank packages
#   - Packages that might be missing from DVD-1
#   - FreeRADIUS packages (specific versions needed)
#   - Packages from preseed pkgsel/include that may not be on DVD-1
#   - Other dependencies
PACKAGES="
    packetfence
    packetfence-pfcmd-suid
    packetfence-config
    packetfence-redis-cache
    packetfence-perl
    packetfence-ntlm-wrapper
    packetfence-golang-daemon
    packetfence-archive-keyring
    fingerbank
    fingerbank-collector
    linux-image-amd64
    linux-headers-amd64
    bind9-dnsutils
    bind9-libs
    bind9-host
    openssh-server
    openssh-client
    openssh-sftp-server
    freeradius
    freeradius-ldap
    freeradius-mysql
    freeradius-utils
    freeradius-rest
    freeradius-redis
    freeradius-common
    mariadb-server
    mariadb-client
    redis-server
    redis-tools
    samba
    haproxy
    keepalived
    monit
    snmpd
    snmp
    vlan
    arping
    lnav
    cgroupfs-mount
    fping
    ipset
    libcache-bdb-perl
    liblog-fast-perl
    libfile-flock-perl
    libcjson1
    liblog-log4perl-perl
    libdbd-sqlite3-perl
    sqlite3
    libdata-powerset-perl
    libcatalyst-perl
    libcatalyst-modules-perl
    libaliased-perl
    libmoosex-types-loadableclass-perl
    libconfig-general-perl
    libreadonly-xs-perl
    libcatalyst-action-rest-perl
    liblwp-protocol-https-perl
    liblwp-protocol-connect-perl
    libjson-perl
    libsql-translator-perl
    libfile-touch-perl
    libglib2.0-0
    libglib2.0-bin
"

# Add Docker repository for docker-ce packages
echo "===> Adding Docker repository for docker-ce packages"
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor | sudo tee ${CHROOT_DIR}/etc/apt/keyrings/docker.gpg > /dev/null
sudo tee ${CHROOT_DIR}/etc/apt/sources.list.d/docker.list > /dev/null << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable
EOF

# Docker packages to download
DOCKER_PACKAGES="docker-ce docker-ce-cli containerd.io"

# Check for locally built PacketFence packages first
LOCAL_BUILD_DIR="${PF_ROOT}/../debian-packages"
if [ -d "${LOCAL_BUILD_DIR}" ]; then
    echo "===> Checking for locally built PacketFence packages in ${LOCAL_BUILD_DIR}"
    if ls ${LOCAL_BUILD_DIR}/*.deb 1> /dev/null 2>&1; then
        echo "Found locally built packages, copying to repository..."
        cp ${LOCAL_BUILD_DIR}/*.deb ${REPO_DIR}/pool/main/ || true
        echo "Locally built packages copied"
    fi
fi

# Also check parent directory for .deb files (CI artifact location)
if ls ${PF_ROOT}/../*.deb 1> /dev/null 2>&1; then
    echo "===> Found .deb files in parent directory, copying to repository..."
    cp ${PF_ROOT}/../*.deb ${REPO_DIR}/pool/main/ || true
fi

# Update and download remaining packages from repositories
echo "===> Updating package lists in chroot"
sudo chroot ${CHROOT_DIR} apt-get update

echo "===> Downloading PacketFence packages and dependencies from repositories"
# Download packages and dependencies (skip if already copied locally)
# Dependencies not on DVD will be downloaded here
sudo chroot ${CHROOT_DIR} apt-get install -y --download-only ${PACKAGES} || true

echo "===> Downloading Docker packages"
sudo chroot ${CHROOT_DIR} apt-get install -y --download-only ${DOCKER_PACKAGES} || true

# Download the packages directly as well
echo "===> Downloading packages directly"
sudo chroot ${CHROOT_DIR} bash -c "apt-get download ${PACKAGES} 2>/dev/null || true"

# Move all downloaded packages to repo
echo "===> Moving downloaded packages to repository"
sudo find ${CHROOT_DIR}/var/cache/apt/archives -name "*.deb" -exec cp {} ${REPO_DIR}/pool/main/ \; 2>/dev/null || true
sudo find ${CHROOT_DIR} -maxdepth 1 -name "*.deb" -exec mv {} ${REPO_DIR}/pool/main/ \; 2>/dev/null || true
# Fix ownership of copied files
sudo chown -R $(id -u):$(id -g) ${REPO_DIR}

# Generate Packages file
echo "===> Generating Packages index"
cd ${REPO_DIR}
dpkg-scanpackages pool/main /dev/null > dists/bookworm/main/binary-amd64/Packages
gzip -k dists/bookworm/main/binary-amd64/Packages

# Create Release file
echo "===> Generating Release file"
cat > ${REPO_DIR}/dists/bookworm/Release << EOF
Origin: PacketFence USB Installer
Label: PacketFence USB Installer
Suite: bookworm
Codename: bookworm
Version: ${PF_RELEASE_VERSION}
Architectures: amd64
Components: main
Description: PacketFence offline installation repository
EOF

# Add checksums to Release file
cd ${REPO_DIR}/dists/bookworm
echo "MD5Sum:" >> Release
for file in main/binary-amd64/Packages main/binary-amd64/Packages.gz; do
    if [ -f "$file" ]; then
        echo " $(md5sum $file | cut -d' ' -f1) $(stat -c%s $file) $file" >> Release
    fi
done

echo "SHA256:" >> Release
for file in main/binary-amd64/Packages main/binary-amd64/Packages.gz; do
    if [ -f "$file" ]; then
        echo " $(sha256sum $file | cut -d' ' -f1) $(stat -c%s $file) $file" >> Release
    fi
done

# Count packages
PKG_COUNT=$(find ${REPO_DIR}/pool -name "*.deb" | wc -l)
REPO_SIZE=$(du -sh ${REPO_DIR} | cut -f1)

echo "=============================================="
echo "PacketFence Repository created successfully!"
echo "Packages: ${PKG_COUNT}"
echo "Size: ${REPO_SIZE}"
echo "Location: ${REPO_DIR}"
echo "=============================================="

# Verify key packages are present
echo ""
echo "===> Verifying key packages in repository:"
KEY_PACKAGES="packetfence fingerbank-collector docker-ce docker-ce-cli containerd.io linux-image-amd64"
MISSING=""
for pkg in ${KEY_PACKAGES}; do
    if find ${REPO_DIR}/pool -name "${pkg}_*.deb" | grep -q .; then
        echo "  [OK] ${pkg}"
    else
        echo "  [MISSING] ${pkg}"
        MISSING="${MISSING} ${pkg}"
    fi
done

if [ -n "${MISSING}" ]; then
    echo ""
    echo "WARNING: Missing packages from pf-repo:${MISSING}"
    echo ""
    echo "This is expected for development builds where packages are not yet published."
    echo "The build will continue - missing packages may be:"
    echo "  - Available on the DVD ISO"
    echo "  - Installed from Debian repositories during preseed"
    echo "  - Not critical for basic installation"
    echo ""
    # Don't fail - let the build continue
fi

echo ""
echo "Note: DVD ISO provides most standard Debian packages."
echo "      This repo adds PacketFence, Docker, and missing dependencies."
echo "=============================================="
