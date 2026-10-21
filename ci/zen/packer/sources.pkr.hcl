# QEMU/KVM build, run in the zen-builder container; the qcow2 becomes
# a VMware OVA in ../build-and-upload.sh.
source "qemu" "debian-12" {
  # the qemu builder uses vm_name verbatim as the disk file name
  vm_name = "${var.vm_name}.qcow2"
  disk_size = "200000"
  format = "qcow2"
  accelerator = "kvm"
  headless = "true"

  # build-time hardware; final appliance sizing is in the VMX template
  cpus = "6"
  memory = "16384"
  disk_interface = "virtio"
  net_device = "virtio-net"

  iso_url = "https://cdimage.debian.org/cdimage/archive/12.4.0/amd64/iso-cd/debian-12.4.0-amd64-netinst.iso"
  iso_checksum = "64d727dd5785ae5fcfd3ae8ffbede5f40cca96f1580aaa2820e8b99dae989d94"

  # boot parameters to preseed questions
  # all parameters below can't be moved to preseed file
  boot_command = [
    "<esc><wait>",
    "auto <wait>",
    "net.ifnames=0 <wait>",
    "apparmor=0 <wait>",
    "install <wait>",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>",
    "kbd-chooser/method=us <wait>",
    "fb=false <wait>",
    "hostname=packetfence <wait>",
    "debconf/frontend=noninteractive <wait>",
    "console-setup/ask_detect=false <wait>",
    "console-keymaps-at/keymap=us <wait>",
    "<enter><wait>"
  ]
  boot_wait = "5s"
  http_directory = "files"
  ssh_username = "root"
  ssh_password = "p@ck3tf3nc3"
  ssh_timeout = "60m"
  shutdown_command = "echo 'p@ck3tf3nc3' | sudo -S poweroff"

  output_directory = "${var.output_qemu_directory}"
}
