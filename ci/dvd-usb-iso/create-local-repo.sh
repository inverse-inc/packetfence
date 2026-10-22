#!/bin/bash
set -o nounset -o pipefail -o errexit

# Ensure /usr/sbin is in PATH (debootstrap is installed there)
export PATH="/usr/sbin:/sbin:${PATH}"

# Use sudo only when not already root (e.g., when running on the host).
# When run inside a container as root, sudo may not be installed.
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Arguments
REPO_DIR=${1:-./repo}
PF_RELEASE_VERSION=${2:-15.1}

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PF_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

source "${SCRIPT_DIR}/../debian-version.conf"

if [ -n "${DEBIAN_SNAPSHOT_DATE:-}" ]; then
    DEBIAN_MIRROR="https://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT_DATE}"
    echo "Using Debian snapshot mirror: ${DEBIAN_MIRROR}"
else
    DEBIAN_MIRROR="http://deb.debian.org/debian"
    echo "WARNING: DEBIAN_SNAPSHOT_DATE not set, using current mirror (may cause version conflicts)"
fi

# PacketFence repository URL configuration
# Available options:
#   - debian-branches: Branch builds (default, for devel/feature branches)
#   - debian-lastrelease: Last release builds (for maintenance releases)
#   - gitlab/PIPELINE_ID: Specific CI pipeline builds
PF_REPO_TYPE=${PF_REPO_TYPE:-debian-branches}

# Build URL based on repo type
# gitlab pipelines use: http://inverse.ca/downloads/PacketFence/gitlab/PIPELINE_ID/debian bookworm main
# branches use: http://inverse.ca/downloads/PacketFence/debian-branches/VERSION bookworm bookworm
# Note: packetfence packages are in debian-branches repo, fingerbank/docker are in debian repo
if [[ "${PF_REPO_TYPE}" == gitlab/* ]]; then
    PF_REPO_BASE_URL="http://inverse.ca/downloads/PacketFence/${PF_REPO_TYPE}/debian"
    PF_REPO_COMPONENT="main"
else
    # Use the PF_REPO_TYPE in the URL (e.g., debian-branches or debian)
    PF_REPO_BASE_URL="http://inverse.ca/downloads/PacketFence/${PF_REPO_TYPE}/${PF_RELEASE_VERSION}"
    PF_REPO_COMPONENT="bookworm"
fi

# URL for dependency packages (fingerbank, docker, freeradius are in debian/VERSION repo)
PF_DEPS_BASE_URL="http://inverse.ca/downloads/PacketFence/debian/${PF_RELEASE_VERSION}"

echo "=============================================="
echo "Creating PacketFence Package Repository"
echo "(Will be appended to DVD repo on ISO)"
echo "=============================================="
echo "REPO_DIR: ${REPO_DIR}"
echo "PF_RELEASE_VERSION: ${PF_RELEASE_VERSION}"
echo "PF_REPO_TYPE: ${PF_REPO_TYPE}"
echo "PF_REPO_BASE_URL: ${PF_REPO_BASE_URL}"
echo "PF_DEPS_BASE_URL: ${PF_DEPS_BASE_URL}"
echo "=============================================="

# Use absolute path for REPO_DIR
REPO_DIR=$(cd "$(dirname "${REPO_DIR}")" && pwd)/$(basename "${REPO_DIR}")

# Create directory structure for PacketFence packages
mkdir -p ${REPO_DIR}/pool/main
mkdir -p ${REPO_DIR}/dists/bookworm/main/binary-amd64

# Create a temporary chroot for package download
CHROOT_DIR=$(mktemp -d)
trap 'echo "Cleaning up chroot..."; ${SUDO} rm -rf "${CHROOT_DIR}"' EXIT

echo "===> Creating minimal chroot for package download"
${SUDO} debootstrap --variant=minbase --include=apt,gnupg,ca-certificates bookworm ${CHROOT_DIR} ${DEBIAN_MIRROR}

if [ -n "${DEBIAN_SNAPSHOT_DATE:-}" ]; then
    ${SUDO} tee ${CHROOT_DIR}/etc/apt/sources.list > /dev/null << EOF
deb [check-valid-until=no] ${DEBIAN_MIRROR} bookworm main
deb [check-valid-until=no] ${DEBIAN_MIRROR} bookworm-updates main
deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT_DATE} bookworm-security main
EOF
    ${SUDO} tee ${CHROOT_DIR}/etc/apt/apt.conf.d/99snapshot > /dev/null << 'EOF'
Acquire::Check-Valid-Until "false";
Acquire::Retries "3";
EOF
fi

# Add PacketFence repository only (we'll use DVD for Debian packages)
echo "===> Configuring PacketFence repository in chroot"
${SUDO} mkdir -p ${CHROOT_DIR}/etc/apt/keyrings
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor | ${SUDO} tee ${CHROOT_DIR}/etc/apt/keyrings/packetfence.gpg > /dev/null
${SUDO} tee ${CHROOT_DIR}/etc/apt/sources.list.d/packetfence.list > /dev/null << EOF
deb [signed-by=/etc/apt/keyrings/packetfence.gpg] ${PF_REPO_BASE_URL} bookworm ${PF_REPO_COMPONENT}
EOF

echo "Configured PacketFence repo: ${PF_REPO_BASE_URL}"

# Add dependencies repo for fingerbank, freeradius, docker packages
# These are always in debian/VERSION repo, separate from packetfence packages
# (packetfence packages are in debian-branches/VERSION or gitlab/PIPELINE_ID repos)
if [[ "${PF_REPO_BASE_URL}" != "${PF_DEPS_BASE_URL}" ]]; then
    echo "===> Adding dependencies repository (fingerbank, freeradius, etc.)"
    ${SUDO} tee ${CHROOT_DIR}/etc/apt/sources.list.d/packetfence_deps.list > /dev/null << EOF
deb [signed-by=/etc/apt/keyrings/packetfence.gpg] ${PF_DEPS_BASE_URL} bookworm bookworm
EOF
    echo "Configured dependencies repo: ${PF_DEPS_BASE_URL}"
fi

# Copy GPG key to repo for later use
${SUDO} cp ${CHROOT_DIR}/etc/apt/keyrings/packetfence.gpg ${REPO_DIR}/packetfence.gpg

# Packages to download (not on DVD or need specific versions)
PACKAGES="
    dpkg-dev
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
    libcjson1
    libdbd-sqlite3-perl
    sqlite3
    libdata-powerset-perl
    libglib2.0-0
    libglib2.0-bin
    liblog-log4perl-perl
    libconfig-inifiles-perl
    liburi-perl
    libregexp-ipv6-perl
    libnet-ssleay-perl
    libio-socket-ssl-perl
    acl
"
# Note: Most perl packages are virtual (provided by packetfence-perl).
# Only list real Debian packages needed for versioned deps or XS modules.

# Add Docker repository
echo "===> Adding Docker repository for docker-ce packages"
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor | ${SUDO} tee ${CHROOT_DIR}/etc/apt/keyrings/docker.gpg > /dev/null
${SUDO} tee ${CHROOT_DIR}/etc/apt/sources.list.d/docker.list > /dev/null << EOF
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
# Retry apt-get update on transient network failures.
apt_update_with_retry() {
    local attempt=1 max=5 delay=5
    while [ ${attempt} -le ${max} ]; do
        if ${SUDO} chroot ${CHROOT_DIR} apt-get update; then
            return 0
        fi
        echo "apt-get update failed (attempt ${attempt}/${max}); retrying in ${delay}s..." >&2
        sleep ${delay}
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
    echo "ERROR: apt-get update failed after ${max} attempts" >&2
    return 1
}
apt_update_with_retry

echo "===> Downloading PacketFence packages and dependencies from repositories"
# Download packages and dependencies (skip if already copied locally)
# Dependencies not on DVD will be downloaded here
${SUDO} chroot ${CHROOT_DIR} apt-get install -y --download-only ${PACKAGES} || true

echo "===> Downloading Docker packages"
${SUDO} chroot ${CHROOT_DIR} apt-get install -y --download-only ${DOCKER_PACKAGES} || true

# Download the packages directly as well
echo "===> Downloading packages directly"
${SUDO} chroot ${CHROOT_DIR} bash -c "apt-get download ${PACKAGES} 2>/dev/null || true"

# Move all downloaded packages to repo
echo "===> Moving downloaded packages to repository"
${SUDO} find ${CHROOT_DIR}/var/cache/apt/archives -name "*.deb" -exec cp {} ${REPO_DIR}/pool/main/ \; 2>/dev/null || true
${SUDO} find ${CHROOT_DIR} -maxdepth 1 -name "*.deb" -exec mv {} ${REPO_DIR}/pool/main/ \; 2>/dev/null || true
# Fix ownership of copied files
${SUDO} chown -R $(id -u):$(id -g) ${REPO_DIR}

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
FILES="main/binary-amd64/Packages main/binary-amd64/Packages.gz"
for algo in MD5Sum:md5sum SHA256:sha256sum; do
    name="${algo%:*}"
    cmd="${algo#*:}"
    echo "${name}:" >> Release
    for file in ${FILES}; do
        [ -f "$file" ] && echo " $($cmd $file | cut -d' ' -f1) $(stat -c%s $file) $file" >> Release
    done
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

# Verify key packages
echo ""
echo "===> Verifying key packages:"
KEY_PACKAGES="packetfence fingerbank-collector docker-ce docker-ce-cli containerd.io"
ALLOW_MISSING_PKGS="${ALLOW_MISSING_PKGS:-}"
MISSING_PKGS=""
for pkg in ${KEY_PACKAGES}; do
    if find ${REPO_DIR}/pool -name "${pkg}_*.deb" | grep -q .; then
        echo "  [OK] ${pkg}"
    elif echo " ${ALLOW_MISSING_PKGS} " | grep -q " ${pkg} "; then
        echo "  [SKIP] ${pkg} (allowed missing via ALLOW_MISSING_PKGS)"
    else
        echo "  [MISSING] ${pkg}"
        MISSING_PKGS="${MISSING_PKGS} ${pkg}"
    fi
done
echo "=============================================="
if [ -n "${MISSING_PKGS}" ]; then
    echo "ERROR: required packages not in local repo:${MISSING_PKGS}" >&2
    echo "Set ALLOW_MISSING_PKGS=\"pkg1 pkg2\" to bypass for known-absent packages." >&2
    exit 1
fi
