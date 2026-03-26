# PacketFence USB Bootable ISO

This directory contains scripts to build a **bootable Debian 12 ISO** with PacketFence pre-installed. Unlike the net-install ISO in `ci/debian-installer/`, this creates a complete live system that can run directly from USB or be installed to disk with all dependencies included offline.

## Features

### Boot Options
The ISO provides multiple boot modes via GRUB menu:

1. **Live System** - Run PacketFence directly from USB/DVD without installation
2. **Live System with Persistence** - Run from USB with ability to save changes
3. **Install to Hard Drive** - Full installation wizard (graphical)
4. **Install to Hard Drive (Text Mode)** - Text-based installation
5. **Recovery Mode** - Debug mode for troubleshooting

### System Features
- ✅ **PacketFence pre-installed** with all dependencies
- ✅ **Offline installation** - No internet required
- ✅ **Persistence support** - Save changes on USB stick
- ✅ **System requirements check** - Validates RAM, CPU, and disk
- ✅ **Auto-configured** - Ready to use after boot
- ✅ **Admin GUI notification** - Shows URL on first login

## System Requirements

### Recommended (Production)
- **RAM**: 8 GB minimum
- **CPU**: 8 cores minimum  
- **Disk**: 50 GB minimum
- **Network**: 2+ NICs recommended

### Minimum (Testing)
- **RAM**: 4 GB
- **CPU**: 2 cores
- **Disk**: 20 GB

The system will display warnings if requirements are not met.

## Building the ISO

### Prerequisites
- Linux system (Debian/Ubuntu preferred)
- Docker installed
- 10+ GB free disk space
- Root/sudo access

### Build Methods

#### Method 1: Using Docker (Recommended)
```bash
cd ci/usb-bootable-iso
make iso
```

This builds the ISO in a clean Debian 12 container and uploads it to storage.

#### Method 2: Local Build (For Testing)
```bash
cd ci/usb-bootable-iso
make local
```

This builds locally without Docker. Requires Debian 12 or similar system.

#### Method 3: Manual Build
```bash
cd ci/usb-bootable-iso
sudo PF_RELEASE="12.0" PF_VERSION="devel" ./build-usb-bootable-iso.sh
```

### Build Output
- **ISO File**: `PacketFence-USB-Bootable-<version>.iso`
- **Checksums**: `.sha256` and `.md5` files
- **Size**: ~2-4 GB (includes all dependencies)

## Using the ISO

### 1. Write to USB Drive

**Linux:**
```bash
sudo dd if=PacketFence-USB-Bootable.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

**Windows:** Use [Rufus](https://rufus.ie/) or [Etcher](https://www.balena.io/etcher/)

**macOS:**
```bash
sudo dd if=PacketFence-USB-Bootable.iso of=/dev/diskX bs=4m
```

⚠️ Replace `/dev/sdX` or `/dev/diskX` with your actual USB device!

### 2. Boot from USB/DVD

1. Insert USB drive or DVD
2. Boot system and select boot device (usually F12, F2, or DEL)
3. Select USB/DVD from boot menu
4. Choose boot option from GRUB menu

### 3. First Boot

After booting (live or installed), you'll see:

```
==========================================
  PacketFence Administration
==========================================

PacketFence has been installed successfully!

The administration GUI is available at:
  https://192.168.1.10:1443/

You will need to complete the initial configuration
through the web setup wizard.

To check system requirements:
  /usr/local/pf/bin/pfcmd checkrequirements

==========================================
```

### 4. Check System Requirements

```bash
/usr/local/pf/bin/pfcmd checkrequirements
```

This will display:
```
==========================================
PacketFence System Requirements Check
==========================================

System Specifications:
  RAM:  8 GB (Recommended: 8 GB)
  CPU:  8 cores (Recommended: 8 cores)
  Disk: 50 GB (Recommended: 50 GB)

✓ All requirements met!
==========================================
```

## Live System Usage

### Running Without Installation
1. Select "**PacketFence - Live System**" from boot menu
2. Wait for system to boot (2-3 minutes)
3. Login as `root` with password `packetfence`
4. Access admin GUI at `https://<IP>:1443/`

### Running With Persistence (USB Only)
1. Select "**PacketFence - Live System with Persistence**"
2. Changes are saved to USB drive
3. Configuration persists across reboots

**Creating Persistence Partition:**
After first boot with persistence option:
```bash
# Create persistence partition on USB
sudo fdisk /dev/sdX  # Create new partition
sudo mkfs.ext4 -L persistence /dev/sdX3
sudo mkdir -p /mnt/persistence
sudo mount /dev/sdX3 /mnt/persistence
echo "/ union" | sudo tee /mnt/persistence/persistence.conf
sudo umount /mnt/persistence
```

## Installation to Hard Drive

### Graphical Installation
1. Select "**PacketFence - Install to Hard Drive**"
2. Follow Debian installer wizard
3. PacketFence is already pre-installed
4. Reboot after installation completes

### Text Mode Installation
1. Select "**PacketFence - Install to Hard Drive (Text Mode)**"
2. Follow text-based installer
3. Useful for remote installations via serial console

## Recovery Mode

For troubleshooting:
1. Select "**PacketFence - Recovery Mode**"
2. Boot with verbose logging and debug options
3. Useful for system repair or investigation

## Architecture Details

### Build Process
1. **live-build** configuration for Debian 12
2. **Hooks** install PacketFence from Inverse repository
3. **Packages** include all dependencies offline
4. **Bootloader** GRUB2 with custom menu
5. **Hybrid ISO** supports USB and DVD

### Included Components
- Debian 12 (Bookworm) base system
- PacketFence latest stable release
- MariaDB database server
- Redis cache server
- All network tools (tcpdump, nmap, etc.)
- System utilities (vim, tmux, htop)
- Development tools (gcc, make, perl)

### File Structure
```
ci/usb-bootable-iso/
├── build-usb-bootable-iso.sh       # Main build script
├── build-usb-bootable-iso-docker.sh # Docker wrapper
├── build-and-upload.sh              # Build & upload orchestrator
├── Makefile                         # Build automation
├── README.md                        # This file
├── .gitignore                       # Git ignore patterns
└── config/                          # Live-build configuration
    ├── bootloaders/                 # GRUB menu configs
    ├── hooks/                       # Installation hooks
    │   └── normal/
    │       ├── 0100-install-packetfence.hook.chroot
    │       └── 0200-system-configuration.hook.chroot
    └── includes.chroot/             # Files to include
        └── usr/local/pf/bin/
            ├── pf-check-requirements    # System requirements checker
            └── pf-first-boot-message    # First boot message script
```

## Differences from Net-Install ISO

| Feature | Net-Install ISO | USB Bootable ISO |
|---------|----------------|------------------|
| **Size** | ~400 MB | ~2-4 GB |
| **Internet Required** | Yes | No |
| **Live Boot** | No | Yes |
| **Persistence** | No | Yes (USB) |
| **Installation Time** | 15-30 min | 5-10 min |
| **Use Case** | Server deployment | Demo, testing, quick deploy |

## Troubleshooting

### Build Issues

**Error: Not enough disk space**
```bash
# Check available space
df -h
# Clean previous builds
make clean
```

**Error: Permission denied**
```bash
# Run with sudo (for local builds)
sudo make local
```

**Error: Docker not found**
```bash
# Install Docker
sudo apt-get install docker.io
sudo systemctl start docker
```

### Boot Issues

**USB not bootable**
- Verify BIOS/UEFI boot mode
- Try different USB port
- Rewrite ISO with different tool

**Kernel panic on boot**
- Verify ISO checksum
- Try "Recovery Mode" option
- Check hardware compatibility

### Runtime Issues

**Can't access admin GUI**
```bash
# Check PacketFence status
sudo systemctl status packetfence

# Check network configuration
ip addr show

# Check firewall
sudo iptables -L
```

**Low performance warnings**
```bash
# Run requirements check
/usr/local/pf/bin/pfcmd checkrequirements

# Upgrade hardware or use full installation
```

## CI/CD Integration

### GitLab CI

The USB bootable ISO is integrated into the GitLab CI pipeline with its own trigger variable.

**Trigger Variable**: `BUILD_PF_IMG_USB_ISO=yes`

**Automatic builds on**:
- `devel` branch (when `BUILD_PF_IMG_USB_ISO=yes` variable is set or commit message contains `build_pf_img_usb_iso=yes`)
- `maintenance/X.Y` branches (schedule, web, or API triggers with variable set)
- Release tags (manual trigger)

**Example - Trigger via commit message**:
```bash
git commit -m "Update USB ISO configuration

build_pf_img_usb_iso=yes"
```

**Example - Trigger via GitLab Web UI**:
1. Go to CI/CD → Pipelines → Run Pipeline
2. Add variable: `BUILD_PF_IMG_USB_ISO` = `yes`
3. Run pipeline

**CI Configuration**:
Add to `.gitlab-ci.yml`:
```yaml
build:usb-iso:
  stage: build
  script:
    - cd ci/usb-bootable-iso
    - make iso
  artifacts:
    paths:
      - ci/usb-bootable-iso/results/
  rules:
    - if: '$BUILD_PF_IMG_USB_ISO == "yes"'
```

### Manual Upload
```bash
# Build
make iso

# Find ISO
ls -lh results/sf/*/PacketFence-USB-Bootable-*.iso

# Upload manually
scp results/sf/v12.0.0/PacketFence-USB-Bootable-v12.0.0.iso user@server:/path/
```

## Security Notes

- **Default root password**: `packetfence` - CHANGE THIS!
- SSH root login enabled for initial setup
- Complete the PacketFence setup wizard to configure admin credentials
- Firewall rules should be configured post-installation
- Use persistence with caution on shared systems

## Contributing

To improve the USB bootable ISO:

1. Edit build scripts in `ci/usb-bootable-iso/`
2. Test locally: `make local`
3. Commit changes to feature branch
4. Submit pull request

## Support

- **Documentation**: https://packetfence.org/doc/
- **Community**: https://packetfence.org/support/community.html
- **Commercial**: https://inverse.ca/

## License

Same license as PacketFence project.

---

**Built with ❤️ by Inverse Inc.**
