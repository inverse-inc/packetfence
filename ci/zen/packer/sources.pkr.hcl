# QEMU/KVM build, run in the zen-builder container; the qcow2 becomes
# a VMware OVA in ../build-and-upload.sh.
source "qemu" "debian-13" {
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

  # Point release and checksum come from ci/debian-version.conf, so the ISO
  # builders and the appliance track one Debian version instead of drifting --
  # this used to pin 12.4.0 while ci/debian-version.conf said 12.14.0.
  #
  # cdimage serves the current point release under release/ and moves it to
  # archive/ once a newer one ships; packer tries iso_urls in order, so listing
  # both means a new point release does not break the build.
  iso_urls = [
    "https://cdimage.debian.org/cdimage/release/${var.debian_version}/amd64/iso-cd/debian-${var.debian_version}-amd64-netinst.iso",
    "https://cdimage.debian.org/cdimage/archive/${var.debian_version}/amd64/iso-cd/debian-${var.debian_version}-amd64-netinst.iso",
  ]
  iso_checksum = "sha256:${var.debian_netinst_sha256}"

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
