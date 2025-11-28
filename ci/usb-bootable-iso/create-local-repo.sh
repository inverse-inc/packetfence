#!/bin/bash
set -o nounset -o pipefail -o errexit

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

# Create directory structure
mkdir -p ${REPO_DIR}/pool/main
mkdir -p ${REPO_DIR}/dists/bookworm/main/binary-amd64

# Create a temporary directory for package download
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# Create a minimal sources.list for downloading packages
cat > ${TEMP_DIR}/sources.list << EOF
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://inverse.ca/downloads/PacketFence/debian/${PF_RELEASE_VERSION} bookworm bookworm
EOF

# Create apt configuration
mkdir -p ${TEMP_DIR}/apt/lists/partial
mkdir -p ${TEMP_DIR}/apt/cache/archives/partial

APT_CONFIG="Dir::Etc::sourcelist=${TEMP_DIR}/sources.list;
Dir::Etc::sourceparts=-;
Dir::State::lists=${TEMP_DIR}/apt/lists;
Dir::Cache=${TEMP_DIR}/apt/cache;
APT::Get::AllowUnauthenticated=true;
Acquire::AllowInsecureRepositories=true;"

# Add PacketFence GPG key
echo "===> Adding PacketFence GPG key"
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor > ${TEMP_DIR}/packetfence.gpg
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Update package lists
echo "===> Updating package lists"
apt-get -o "${APT_CONFIG}" update 2>/dev/null || true

# List of base packages needed for installation
BASE_PACKAGES="
    sudo
    bzip2
    acpid
    cryptsetup
    zlib1g-dev
    wget
    curl
    dkms
    make
    nfs-common
    net-tools
    build-essential
    linux-headers-amd64
    gnupg2
    apt-transport-https
    tmux
    tcpdump
    lnav
    apg
    sysstat
    bsd-mailx
    cgroupfs-mount
    openssh-server
"

# PacketFence and its major dependencies
PF_PACKAGES="
    packetfence
    mariadb-server
    redis-server
    docker.io
    containerd
    freeradius
    freeradius-utils
    freeradius-ldap
    freeradius-postgresql
    freeradius-mysql
    freeradius-krb5
    snmp
    snmptrapd
    snmpd
    libsnmp-dev
    nodejs
    fingerbank-collector
"

# Download all packages with dependencies
echo "===> Downloading packages (this may take a while)..."
cd ${TEMP_DIR}

# Download packages
apt-get -o "${APT_CONFIG}" download \
    --print-uris \
    ${BASE_PACKAGES} ${PF_PACKAGES} 2>/dev/null | \
    grep "^'" | \
    cut -d"'" -f2 > ${TEMP_DIR}/package_urls.txt || true

# Also get dependencies
apt-get -o "${APT_CONFIG}" install \
    --download-only \
    --print-uris \
    -y \
    ${BASE_PACKAGES} ${PF_PACKAGES} 2>/dev/null | \
    grep "^'" | \
    cut -d"'" -f2 >> ${TEMP_DIR}/package_urls.txt || true

# Remove duplicates
sort -u ${TEMP_DIR}/package_urls.txt > ${TEMP_DIR}/package_urls_unique.txt

# Download packages using wget for better progress
echo "===> Downloading $(wc -l < ${TEMP_DIR}/package_urls_unique.txt) packages..."
mkdir -p ${TEMP_DIR}/packages
cd ${TEMP_DIR}/packages

# Download in parallel using xargs
cat ${TEMP_DIR}/package_urls_unique.txt | xargs -P 10 -I {} wget -q --show-progress -nc {} 2>/dev/null || true

# Alternative: use apt-get download directly
echo "===> Using apt-get to download remaining packages..."
apt-get -o "${APT_CONFIG}" download ${BASE_PACKAGES} ${PF_PACKAGES} 2>/dev/null || true

# Also download dependencies
for pkg in ${BASE_PACKAGES} ${PF_PACKAGES}; do
    apt-get -o "${APT_CONFIG}" download $(apt-cache -o "${APT_CONFIG}" depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances ${pkg} 2>/dev/null | grep "^\w" | sort -u) 2>/dev/null || true
done

# Move all downloaded packages to repo
echo "===> Moving packages to repository"
find ${TEMP_DIR} -name "*.deb" -exec mv {} ${REPO_DIR}/pool/main/ \; 2>/dev/null || true
# Note: Don't copy from /var/cache/apt/archives as it contains unrelated host packages

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
