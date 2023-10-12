# VirtualBox builds
source "virtualbox-iso" "debian-11" {
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
  iso_url = "https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/debian-11.8.0-amd64-netinst.iso"
  iso_checksum = "sha256:d7a74813a734083df30c8d35784926deaa36bc41e5c0766388e9f591ab056b72"
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
