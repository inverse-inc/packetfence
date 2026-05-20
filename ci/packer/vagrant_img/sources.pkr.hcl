# Vagrant EL 8 builds
source "vagrant" "el-8" {
  communicator = "ssh"
  source_path = "generic/rhel8"
  box_version = "3.2.24"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
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
