# QEMU EL 8 builds — boots from existing generic/rhel8 base box (disk_image=true).
# No installer, no kickstart. The base box already has vagrant/vagrant credentials.
source "qemu" "el-8" {
  disk_image   = true
  iso_url      = var.rhel8_disk_image_url
  iso_checksum = var.rhel8_disk_image_checksum

  communicator           = "ssh"
  ssh_username           = "vagrant"
  ssh_private_key_file   = "provisioners/keys/vagrant_insecure_key"
  ssh_timeout            = "30m"

  cpus      = 4
  memory    = 4096
  # generic/rhel8 ships a 128 GB virtual qcow2; setting a smaller target
  # makes qemu-img demand --shrink and aborts the build.
  disk_size = 131072

  accelerator  = "kvm"
  machine_type = "q35"

  disk_interface = "virtio"
  net_device     = "virtio-net"

  headless         = true
  output_directory = "${var.output_dir}/tmp"
  vm_name          = "rhel8.qcow2"

  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"

  format = "qcow2"
}

# QEMU Debian 12 builds — boots from existing debian/bookworm64 base box (disk_image=true)
# No installer, no preseed. The base box already has vagrant/vagrant credentials.
source "qemu" "debian-12" {
  disk_image   = true
  iso_url      = var.disk_image_url
  iso_checksum = var.disk_image_checksum

  communicator           = "ssh"
  ssh_username           = "vagrant"
  ssh_private_key_file   = "provisioners/keys/vagrant_insecure_key"
  ssh_timeout            = "10m"

  cpus      = 4
  memory    = 4096
  disk_size = 102400

  accelerator  = "kvm"
  machine_type = "q35"

  disk_interface = "virtio"
  net_device     = "virtio-net"

  headless         = true
  output_directory = "${var.output_dir}/tmp"
  vm_name          = "debian-12.qcow2"

  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"

  format = "qcow2"
}

# QEMU Debian 11 (Bullseye) builds — boots from existing debian/bullseye64 base box (disk_image=true)
# Used for the AD (Samba4) vagrant box. ssh_timeout is longer to accommodate two reboots
# during Samba provisioning.
source "qemu" "bullseye-11" {
  disk_image   = true
  iso_url      = var.bullseye_disk_image_url
  iso_checksum = var.bullseye_disk_image_checksum

  communicator           = "ssh"
  ssh_username           = "vagrant"
  ssh_private_key_file   = "provisioners/keys/vagrant_insecure_key"
  ssh_timeout            = "30m"

  cpus      = 2
  memory    = 2048
  disk_size = 102400

  accelerator  = "kvm"
  machine_type = "q35"

  disk_interface = "virtio"
  net_device     = "virtio-net"

  headless         = true
  output_directory = "${var.output_dir}/tmp"
  vm_name          = "bullseye-11.qcow2"

  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"

  format = "qcow2"
}
