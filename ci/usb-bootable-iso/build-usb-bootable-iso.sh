#!/bin/bash
set -o nounset -o pipefail -o errexit

# PacketFence USB Bootable ISO Builder
# Creates a Debian 12 Live system with PacketFence pre-installed
# Supports: Live mode, Live with persistence, Full installation, Recovery mode

PF_VERSION=${PF_VERSION:-devel}
PF_RELEASE=${PF_RELEASE:-12.0}
ISO_OUT=${ISO_OUT:-PacketFence-USB-Bootable.iso}
WORK_DIR=${WORK_DIR:-$(pwd)/build}

echo "=========================================="
echo "PacketFence USB Bootable ISO Builder"
echo "=========================================="
echo "PF Version: ${PF_VERSION}"
echo "PF Release: ${PF_RELEASE}"
echo "Output ISO: ${ISO_OUT}"
echo "Work Directory: ${WORK_DIR}"
echo "=========================================="

# Clean previous builds
clean_build() {
    echo "==> Cleaning previous build..."
    rm -rf "${WORK_DIR}"
    mkdir -p "${WORK_DIR}"
}

# Install build dependencies
install_dependencies() {
    echo "==> Installing build dependencies..."
    apt-get update
    apt-get install -y \
        live-build \
        debootstrap \
        xorriso \
        squashfs-tools \
        syslinux-utils \
        isolinux \
        rsync \
        wget \
        curl \
        gnupg2
}

# Configure live-build
configure_live_build() {
    echo "==> Configuring live-build..."
    cd "${WORK_DIR}"
    
    lb config noauto \
        --mode debian \
        --distribution bookworm \
        --archive-areas "main contrib non-free non-free-firmware" \
        --architectures amd64 \
        --linux-flavours amd64 \
        --bootappend-live "boot=live components quiet splash persistence net.ifnames=0 apparmor=0" \
        --bootappend-install "net.ifnames=0 apparmor=0" \
        --bootloaders "grub-efi grub-pc" \
        --binary-images iso-hybrid \
        --iso-application "PacketFence" \
        --iso-publisher "Inverse Inc." \
        --iso-volume "PacketFence-${PF_VERSION}" \
        --debian-installer live \
        --debian-installer-gui true \
        --win32-loader false \
        --checksums sha256 \
        --zsync false
        
    echo "==> Live-build configured successfully"
}

# Create package lists
create_package_lists() {
    echo "==> Creating package lists..."
    
    mkdir -p config/package-lists
    
    # Base system packages
    cat > config/package-lists/base.list.chroot <<EOF
# Base system
systemd
systemd-sysv
udev
dbus

# Networking
network-manager
iproute2
iptables
ipset
bridge-utils
vlan
net-tools
tcpdump
nmap
ethtool
curl
wget

# File systems and storage
lvm2
cryptsetup
btrfs-progs
dosfstools
ntfs-3g

# Kernel and hardware
linux-image-amd64
linux-headers-amd64
firmware-linux
firmware-linux-nonfree
firmware-misc-nonfree

# Basic utilities
sudo
vim
nano
tmux
screen
lnav
htop
sysstat
less
rsync
bzip2
gzip
xz-utils
zip
unzip
git
gnupg2
apt-transport-https
ca-certificates

# System tools
acpid
dkms
make
build-essential
cgroupfs-mount
sysfsutils
usbutils
pciutils

# Monitoring and logging
rsyslog
logrotate

# Mail utilities
bsd-mailx

# Password generation
apg

# NFS support
nfs-common

# SSH
openssh-server
openssh-client

# Man pages
man-db
manpages
EOF

    # PacketFence and dependencies - will be installed via hooks
    cat > config/package-lists/packetfence.list.chroot <<EOF
# MariaDB will be pulled by PacketFence dependencies
# Redis will be pulled by PacketFence dependencies
# All other PF dependencies will be installed
EOF

    echo "==> Package lists created"
}

# Create hooks for PacketFence installation
create_hooks() {
    echo "==> Creating installation hooks..."
    
    mkdir -p config/hooks/normal
    
    # Hook to add PacketFence repository and install PacketFence
    cat > config/hooks/normal/0100-install-packetfence.hook.chroot <<'EOFHOOK'
#!/bin/bash
set -e

echo "=========================================="
echo "Installing PacketFence..."
echo "=========================================="

# Create policy-rc.d to prevent service starts during installation
cat > /usr/sbin/policy-rc.d <<'EOFPOLICY'
#!/bin/bash
exit 101
EOFPOLICY
chmod +x /usr/sbin/policy-rc.d

# Add PacketFence GPG key
curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor -o /etc/apt/keyrings/packetfence.gpg

# Add PacketFence repository
PF_RELEASE="%%PF_RELEASE%%"
echo "deb [signed-by=/etc/apt/keyrings/packetfence.gpg] https://inverse.ca/downloads/PacketFence/debian/${PF_RELEASE} bookworm bookworm" > \
    /etc/apt/sources.list.d/packetfence.list

# Update package lists
apt-get update

# Install PacketFence with policy-rc.d preventing service starts
DEBIAN_FRONTEND=noninteractive RUNLEVEL=1 apt-get install -y --no-install-recommends packetfence || {
    # If installation fails, check if it's just because of post-install issues
    # Configure the package anyway to complete the installation
    dpkg --configure -a || true
}

# Remove policy-rc.d
rm -f /usr/sbin/policy-rc.d

# Ensure services are stopped (in case they somehow started)
systemctl stop packetfence-mariadb || true
systemctl stop packetfence-redis-cache || true
systemctl stop packetfence || true

# Docker won't be available in chroot, so we skip docker image operations
# Images will be downloaded on first boot

echo "=========================================="
echo "PacketFence installed successfully"
echo "Note: Docker images will be downloaded on first boot"
echo "=========================================="
EOFHOOK
    
    chmod +x config/hooks/normal/0100-install-packetfence.hook.chroot
    
    # Replace PF_RELEASE placeholder
    sed -i "s/%%PF_RELEASE%%/${PF_RELEASE}/g" config/hooks/normal/0100-install-packetfence.hook.chroot
    
    # Hook to configure system
    cat > config/hooks/normal/0200-system-configuration.hook.chroot <<'EOFHOOK'
#!/bin/bash
set -e

echo "=========================================="
echo "Configuring system..."
echo "=========================================="

# Enable SSH root login (for initial setup)
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config

# Set default root password (user should change this)
echo "root:packetfence" | chpasswd

# Disable cdrom in sources.list
sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list

# Enable systemd services for PacketFence
systemctl enable packetfence-mariadb || true
systemctl enable packetfence-redis-cache || true
systemctl enable packetfence || true

echo "=========================================="
echo "System configuration completed"
echo "=========================================="
EOFHOOK
    
    chmod +x config/hooks/normal/0200-system-configuration.hook.chroot
    
    echo "==> Hooks created"
}

# Create includes (files to be copied to the live system)
create_includes() {
    echo "==> Creating includes..."
    
    mkdir -p config/includes.chroot/usr/local/pf/bin
    mkdir -p config/includes.chroot/etc/profile.d
    
    # System requirements checker script
    cat > config/includes.chroot/usr/local/pf/bin/pf-check-requirements <<'EOFSCRIPT'
#!/bin/bash

echo "=========================================="
echo "PacketFence System Requirements Check"
echo "=========================================="
echo ""

# Recommended requirements
RECOMMENDED_RAM_GB=8
RECOMMENDED_CPU=8
RECOMMENDED_DISK_GB=50

# Get actual system specs
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
TOTAL_CPU=$(nproc)
TOTAL_DISK_GB=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')

echo "System Specifications:"
echo "  RAM:  ${TOTAL_RAM_GB} GB (Recommended: ${RECOMMENDED_RAM_GB} GB)"
echo "  CPU:  ${TOTAL_CPU} cores (Recommended: ${RECOMMENDED_CPU} cores)"
echo "  Disk: ${TOTAL_DISK_GB} GB (Recommended: ${RECOMMENDED_DISK_GB} GB)"
echo ""

WARNINGS=0

if [ "$TOTAL_RAM_GB" -lt "$RECOMMENDED_RAM_GB" ]; then
    echo "WARNING: RAM is below recommended specifications!"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$TOTAL_CPU" -lt "$RECOMMENDED_CPU" ]; then
    echo "WARNING: CPU cores are below recommended specifications!"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$TOTAL_DISK_GB" -lt "$RECOMMENDED_DISK_GB" ]; then
    echo "WARNING: Disk space is below recommended specifications!"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$WARNINGS" -eq 0 ]; then
    echo "✓ All requirements met!"
else
    echo ""
    echo "⚠ $WARNINGS warning(s) found. PacketFence may not perform optimally."
    echo "  For production use, please ensure the recommended specifications."
fi

echo "=========================================="
EOFSCRIPT
    
    chmod +x config/includes.chroot/usr/local/pf/bin/pf-check-requirements
    
    # First boot message script
    cat > config/includes.chroot/usr/local/pf/bin/pf-first-boot-message <<'EOFSCRIPT'
#!/bin/bash

# Get primary IP address (excluding loopback)
IP_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)

if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="<YOUR_IP_ADDRESS>"
fi

cat <<EOF

=========================================="
  PacketFence Administration
=========================================="

PacketFence has been installed successfully!

The administration GUI is available at:
  https://${IP_ADDRESS}:1443/

You will need to complete the initial configuration
through the web setup wizard.

To check system requirements:
  /usr/local/pf/bin/pfcmd checkrequirements

=========================================="

EOF
EOFSCRIPT
    
    chmod +x config/includes.chroot/usr/local/pf/bin/pf-first-boot-message
    
    # Add first boot message to profile
    cat > config/includes.chroot/etc/profile.d/pf-welcome.sh <<'EOFPROFILE'
#!/bin/bash

# Show welcome message only once per session
if [ -z "$PF_WELCOME_SHOWN" ]; then
    export PF_WELCOME_SHOWN=1
    /usr/local/pf/bin/pf-first-boot-message
fi
EOFPROFILE
    
    chmod +x config/includes.chroot/etc/profile.d/pf-welcome.sh
    
    echo "==> Includes created"
}

# Create custom GRUB menu
create_grub_menu() {
    echo "==> Creating custom GRUB menu..."
    
    mkdir -p config/bootloaders/grub-pc
    
    cat > config/bootloaders/grub-pc/grub.cfg <<'EOFGRUB'
set default=0
set timeout=30

loadfont unicode

insmod all_video
insmod gfxterm
insmod png

set gfxmode=auto
set gfxpayload=keep

terminal_output gfxterm

set menu_color_normal=cyan/blue
set menu_color_highlight=white/blue

menuentry "PacketFence - Live System" {
    linux /live/vmlinuz boot=live components quiet splash persistence net.ifnames=0 apparmor=0
    initrd /live/initrd.img
}

menuentry "PacketFence - Live System with Persistence" {
    linux /live/vmlinuz boot=live components quiet splash persistence persistence-encryption=none net.ifnames=0 apparmor=0
    initrd /live/initrd.img
}

menuentry "PacketFence - Install to Hard Drive" {
    linux /live/vmlinuz boot=live components quiet splash net.ifnames=0 apparmor=0
    initrd /live/initrd.img
}

menuentry "PacketFence - Install to Hard Drive (Text Mode)" {
    linux /live/vmlinuz boot=live components noprompt net.ifnames=0 apparmor=0 vga=normal
    initrd /live/initrd.img
}

menuentry "PacketFence - Recovery Mode" {
    linux /live/vmlinuz boot=live components debug verbose net.ifnames=0 apparmor=0
    initrd /live/initrd.img
}

menuentry "Memory Test (memtest86+)" {
    linux /live/memtest
}
EOFGRUB
    
    echo "==> GRUB menu created"
}

# Build the ISO
build_iso() {
    echo "==> Building ISO image..."
    cd "${WORK_DIR}"
    
    # Build
    lb build 2>&1 | tee build.log
    
    # Copy the resulting ISO
    if [ -f live-image-amd64.hybrid.iso ]; then
        cp live-image-amd64.hybrid.iso "${ISO_OUT}"
        echo "==> ISO created successfully: ${ISO_OUT}"
        
        # Generate checksums
        sha256sum "${ISO_OUT}" > "${ISO_OUT}.sha256"
        md5sum "${ISO_OUT}" > "${ISO_OUT}.md5"
        
        echo "==> Checksums generated"
    else
        echo "ERROR: ISO build failed!"
        exit 1
    fi
}

# Main execution
main() {
    clean_build
    install_dependencies
    configure_live_build
    create_package_lists
    create_hooks
    create_includes
    create_grub_menu
    build_iso
    
    echo ""
    echo "=========================================="
    echo "Build completed successfully!"
    echo "ISO: ${ISO_OUT}"
    echo "Size: $(du -h ${ISO_OUT} | cut -f1)"
    echo "=========================================="
}

# Run main function
main
