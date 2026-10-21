# PacketFence DVD-USB ISO

Build a self-contained, offline DVD-USB installer for PacketFence on Debian 12 (Bookworm).

The ISO bundles the Debian DVD, all PacketFence packages, dependencies, and pre-downloaded Docker images so that no internet connection is required during installation.

## Requirements

### Build machine

- **OS:** Debian 12 / Ubuntu 22.04+ (amd64)
- **Disk space:** ~30 GB free (base ISO ~3.8 GB + work directories + final ISO)
- **RAM:** 4 GB minimum
- **Internet:** Required during build to download packages and Docker images
- **Root/sudo:** Required for `debootstrap` and package operations

#### Required packages

Installed automatically by the build script if missing:

- `debootstrap`
- `xorriso`
- `dpkg-dev`
- `cpio`
- `gnupg`
- `docker` (Docker Engine, from docker.com or `docker.io`)

### Target server (installation)

- **Architecture:** x86_64 / amd64
- **RAM:** 8 GB minimum (16 GB recommended)
- **Disk:** 100 GB minimum
- **Boot:** BIOS (Legacy) or UEFI (Secure Boot must be disabled)
- **USB port:** USB 2.0 or higher

### USB key

- **Capacity:** 16 GB minimum (the ISO is typically 6-8 GB)

## Building the ISO

### From a local checkout

```bash
cd ci/dvd-usb-iso
make iso
```

The output file is `PacketFence-DVD-USB-ISO-<version>.iso`.

### Override version or output name

```bash
make iso PF_VERSION=15.1.0 ISO_OUT=packetfence-custom.iso
```

### Skip work directory cleanup (faster rebuilds while debugging)

```bash
SKIP_CLEAN=1 make iso
```

### Clean all build artifacts

```bash
make clean
```

### From GitLab CI

Trigger a pipeline with the variable `BUILD_PF_IMG_DVD_USB_ISO=yes`, or include `build_pf_img_dvd_usb_iso=yes` in the commit message. The PPA must be published first.

## Writing the ISO to a USB key

**Warning:** This will erase all data on the USB device.

### 1. Identify the USB device

Plug in the USB key, then find its device name:

```bash
lsblk
```

Look for the USB device (e.g., `/dev/sdb`). Make sure you identify the correct device — **not** your system disk.

### 2. Write the ISO

Use `dd` to write a raw copy of the ISO to the USB device. The ISO is built as a hybrid image (isohybrid), so it is directly bootable when written this way:

```bash
sudo dd if=PacketFence-DVD-USB-ISO-<version>.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your actual USB device (e.g., `/dev/sdb`).

**Important:**
- Write to the **device** (`/dev/sdX`), not a partition (`/dev/sdX1`).
- Do **not** simply copy the ISO file onto a FAT/NTFS formatted USB key — it will not boot.

#### Alternative tools

- **[balenaEtcher](https://etcher.balena.io/)** — graphical, works on Linux/macOS/Windows
- **[Ventoy](https://www.ventoy.net/)** — multi-ISO USB tool, copy the `.iso` file onto a Ventoy-prepared USB key

## Installing PacketFence from the USB key

1. Plug the USB key into the target server.
2. Boot from the USB key (press F2/F10/F11/F12/Del during POST to access the boot menu, depending on hardware).
3. Select **Install PacketFence (USB Offline)** from the boot menu.
4. Follow the Debian installer prompts:
   - Choose language, keyboard layout, and timezone.
   - Configure the network (DHCP or manual).
   - Set the root password.
   - Partition the disk (guided or manual).
   - Select the boot loader disk.
5. The installer runs the post-installation script automatically (Phase A: installs all dependencies from the ISO).
6. **Remove the USB key** when prompted to reboot.
7. On first boot, a systemd service completes the installation (Phase B: starts Docker, loads container images, installs PacketFence). This takes 10–40 minutes depending on hardware. Progress is shown on the login screen.
8. Once complete, log in as root and run:
   ```bash
   /usr/local/pf/bin/pfcmd configreload hard
   ```
9. Access the web interface at `https://<server-ip>:1443`.

## Testing with QEMU/KVM

You can test the ISO in a virtual machine without a physical server or USB key.

### Requirements

```bash
sudo apt install qemu-system-x86 ovmf
```

### Create a virtual disk

```bash
qemu-img create -f qcow2 /tmp/pf-test.qcow2 40G
```

### Boot in UEFI mode

```bash
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -enable-kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -cdrom PacketFence-DVD-USB-ISO-<version>.iso \
  -drive file=/tmp/pf-test.qcow2,format=qcow2 \
  -boot d \
  -net nic -net user
```

### Boot in BIOS (Legacy) mode

```bash
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -enable-kvm \
  -cdrom PacketFence-DVD-USB-ISO-<version>.iso \
  -drive file=/tmp/pf-test.qcow2,format=qcow2 \
  -boot d \
  -net nic -net user
```

### Simulate USB boot

Since the ISO is a hybrid image, you can also boot it as a raw disk to simulate what happens when it is `dd`'d onto a USB key:

```bash
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -enable-kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -drive file=PacketFence-DVD-USB-ISO-<version>.iso,format=raw,if=virtio,readonly=on \
  -drive file=/tmp/pf-test.qcow2,format=qcow2,if=virtio \
  -boot c \
  -net nic -net user
```

## Troubleshooting

### USB key does not boot

- **Secure Boot:** Disable Secure Boot in the server BIOS/UEFI settings.
- **Boot mode mismatch:** Ensure the server boot mode (BIOS or UEFI) is compatible. The ISO supports both.
- **Wrong write method:** The ISO must be written as a raw image (`dd` or Etcher), not copied as a file.
- **Wrong device:** Verify you wrote to the device (`/dev/sdX`), not a partition (`/dev/sdX1`).

### First boot takes a long time

This is expected. Phase B loads all Docker images and installs PacketFence. Monitor progress:

```bash
tail -f /var/log/packetfence-first-boot.log
```

### First boot failed

Check the log and retry:

```bash
cat /var/log/packetfence-first-boot.log
/usr/local/bin/packetfence-first-boot.sh
```

## Build process overview

1. Download base Debian 12 DVD ISO (~3.8 GB)
2. Create local APT repository with PacketFence packages and dependencies
3. Pre-download all PacketFence Docker images (~30 containers)
4. Extract the base Debian ISO
5. Generate and inject the preseed configuration into the installer initrd
6. Add the local APT repository and Docker images to the ISO
7. Update boot menu configurations (ISOLINUX for BIOS, GRUB for UEFI)
8. Build the final hybrid ISO with `xorriso`

## Files

| File | Description |
|------|-------------|
| `Makefile` | Build targets: `iso`, `upload`, `clean` |
| `build-usb-bootable-iso.sh` | Main build orchestration script |
| `create-local-repo.sh` | Downloads and assembles the offline APT repository |
| `predownload-docker-images.sh` | Pulls and archives all Docker images |
| `preseed-offline.cfg.tmpl` | Debian preseed template for unattended installation |
| `postinst-offline.sh` | Post-installation script (Phase A + Phase B first-boot) |
| `grub.cfg` | GRUB boot menu (UEFI) |
| `menu.cfg` | ISOLINUX boot menu (BIOS) |
| `gtk.cfg` | ISOLINUX graphical installer menu |
| `drkgtk.cfg` | ISOLINUX dark contrast menu |
| `build-and-upload.sh` | Build and upload to Linode S3 |
