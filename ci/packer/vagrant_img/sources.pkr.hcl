# Vagrant EL 8 builds
source "vagrant" "el-8" {
  communicator = "ssh"
  source_path = "generic/rhel8"
  box_version = "3.2.24"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
}

# QEMU Debian 12 builds — boots official netinst ISO, unattended via preseed
source "qemu" "debian-12" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  communicator = "ssh"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout  = "30m"

  cpus      = 2
  memory    = 2048
  disk_size = 40960

  accelerator  = "kvm"
  machine_type = "q35"

  disk_interface = "virtio"
  net_device     = "virtio-net"

  headless = true
  output_directory = "${var.output_dir}"
  output_filename  = "debian-12.qcow2"

  http_directory = "http"

  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=vagrant domain=local ",
    "interface=auto netcfg/dhcp_timeout=60 ",
    "DEBIAN_FRONTEND=noninteractive ",
    "<enter><wait>"
  ]

  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"

  format = "qcow2"
}
