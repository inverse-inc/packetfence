# VirtualBox builds
source "virtualbox-iso" "debian-12" {
  vm_name = "${var.vm_name}"
  disk_size = "200000"
  guest_os_type = "Debian_64"
  hard_drive_interface = "scsi"
  headless = "true"

  # hardware used to **build VM**
  cpus = "2"
  memory = "2048"

  # change hardware configuration before exporting VM
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--cpus", "4"],
    ["modifyvm", "{{.Name}}", "--memory", "16384"],
    ["modifyvm", "{{.Name}}", "--uartmode1", "disconnected"],
    ["storagectl", "{{.Name}}", "--name", "IDE Controller", "--remove"]
  ]
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
  # export
  format = "ova"
  output_directory = "${var.output_vbox_directory}"
}
