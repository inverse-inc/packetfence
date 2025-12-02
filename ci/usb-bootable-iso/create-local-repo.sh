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
echo "Creating Local APT Repository"
echo "=============================================="
echo "REPO_DIR: ${REPO_DIR}"
echo "PF_RELEASE_VERSION: ${PF_RELEASE_VERSION}"
echo "=============================================="

# Use absolute path for REPO_DIR
REPO_DIR=$(cd "$(dirname "${REPO_DIR}")" && pwd)/$(basename "${REPO_DIR}")

# Create directory structure
mkdir -p ${REPO_DIR}/pool/main
mkdir -p ${REPO_DIR}/dists/bookworm/main/binary-amd64

# Create a temporary chroot for clean package resolution
CHROOT_DIR=$(mktemp -d)
trap "echo 'Cleaning up chroot...'; rm -rf ${CHROOT_DIR}" EXIT

echo "===> Creating minimal chroot for package download"
debootstrap --variant=minbase --include=apt,gnupg,ca-certificates bookworm ${CHROOT_DIR} http://deb.debian.org/debian

# Configure repositories in chroot
cat > ${CHROOT_DIR}/etc/apt/sources.list << EOF
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

# Add PacketFence repository
mkdir -p ${CHROOT_DIR}/etc/apt/keyrings
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor > ${CHROOT_DIR}/etc/apt/keyrings/packetfence.gpg
cat > ${CHROOT_DIR}/etc/apt/sources.list.d/packetfence.list << EOF
deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/${PF_RELEASE_VERSION} bookworm bookworm
EOF

# Copy GPG key to repo for later use
cp ${CHROOT_DIR}/etc/apt/keyrings/packetfence.gpg ${REPO_DIR}/packetfence.gpg

# List of packages to install (will pull all dependencies)
PACKAGES="
    packetfence
    docker.io
    containerd
    mariadb-server
    redis-server
    freeradius
    freeradius-utils
    freeradius-ldap
    freeradius-postgresql
    freeradius-mysql
    freeradius-krb5
    snmp
    snmptrapd
    snmpd
    fingerbank-collector
    sudo
    openssh-server
    curl
    wget
    gnupg2
    ca-certificates
    apt-transport-https
    net-tools
    tcpdump
    tmux
    lnav
"

# Update and download all packages with dependencies in chroot
echo "===> Updating package lists in chroot"
chroot ${CHROOT_DIR} apt-get update

echo "===> Downloading all packages with dependencies"
# Use apt-get install with download-only to get ALL dependencies
chroot ${CHROOT_DIR} apt-get install -y --download-only -o APT::Install-Recommends=0 ${PACKAGES} || true

# Some packages may fail due to pre-depends, try downloading them directly
echo "===> Downloading any missing packages"
chroot ${CHROOT_DIR} bash -c "apt-get download ${PACKAGES} 2>/dev/null || true"

# Download dependencies recursively using apt-cache
echo "===> Resolving and downloading all dependencies"
chroot ${CHROOT_DIR} bash -c '
PACKAGES="packetfence docker.io containerd mariadb-server redis-server freeradius fingerbank-collector"
for pkg in $PACKAGES; do
    deps=$(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances "$pkg" 2>/dev/null | grep "^\w" | grep -v "^<" | sort -u)
    apt-get download $deps 2>/dev/null || true
done
'

# Move all downloaded packages to repo
echo "===> Moving packages to repository"
find ${CHROOT_DIR}/var/cache/apt/archives -name "*.deb" -exec cp {} ${REPO_DIR}/pool/main/ \; 2>/dev/null || true
find ${CHROOT_DIR} -maxdepth 1 -name "*.deb" -exec mv {} ${REPO_DIR}/pool/main/ \; 2>/dev/null || true

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
echo "Local APT Repository created successfully!"
echo "Packages: ${PKG_COUNT}"
echo "Size: ${REPO_SIZE}"
echo "Location: ${REPO_DIR}"
echo "=============================================="

# Verify key packages are present
echo ""
echo "===> Verifying key packages in repository:"
KEY_PACKAGES="packetfence packetfence-pfcmd-suid docker.io containerd mariadb-server redis-server freeradius fingerbank-collector"
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
    echo "WARNING: Missing packages:${MISSING}"
    echo "The offline installation may fail!"
    exit 1
fi

echo ""
echo "===> Package breakdown by source:"
echo "  PacketFence packages: $(find ${REPO_DIR}/pool -name "packetfence*.deb" -o -name "fingerbank*.deb" | wc -l)"
echo "  Docker packages: $(find ${REPO_DIR}/pool -name "docker*.deb" -o -name "containerd*.deb" | wc -l)"
echo "  MariaDB packages: $(find ${REPO_DIR}/pool -name "mariadb*.deb" -o -name "mysql*.deb" -o -name "galera*.deb" | wc -l)"
echo "  FreeRADIUS packages: $(find ${REPO_DIR}/pool -name "freeradius*.deb" | wc -l)"
echo "  Other packages: $(find ${REPO_DIR}/pool -name "*.deb" | wc -l) total"
echo "=============================================="
