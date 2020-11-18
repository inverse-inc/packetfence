# VirtualBox builds
source "virtualbox-iso" "centos-7" {
  vm_name = "${var.vm_name}"
  disk_size = "40000"
  guest_os_type = "RedHat_64"
  hard_drive_interface = "scsi"
  headless = "true"

  # hardware used to **build VM**
  cpus = "2"
  memory = "2048"

  # change hardware configuration before exporting VM
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--cpus", "4"],
    ["modifyvm", "{{.Name}}", "--memory", "12288"],
    ["modifyvm", "{{.Name}}", "--uartmode1", "disconnected"],
    ["storagectl", "{{.Name}}", "--name", "IDE Controller", "--remove"]
  ]
  iso_url = "http://centos.mirror.iweb.ca/7/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso"
  iso_checksum = "sha256:07b94e6b1a0b0260b94c83d6bb76b26bf7a310dc78d7a9c7432809fb9bc6194a"
  boot_command = [
    "<up><tab><spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos7.ks.cfg<return>"
  ]
  http_directory = "files"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout = "60m"
  shutdown_command = "sudo poweroff"
  # export
  format = "ova"
  output_directory = "${var.output_vbox_directory}"
}

# VMware builds
source "vmware-iso" "centos-7" {
  vm_name = "${var.vm_name}"
  disk_size = "40000"
  guest_os_type = "centos-64"
  disk_adapter_type = "scsi"
  headless = "true"
  vmx_data = {
    memsize = 12288
    numvcpus = 4
  } 
  iso_url = "http://centos.mirror.iweb.ca/7/isos/x86_64/CentOS-7-x86_64-Minimal-2003.iso"
  iso_checksum = "sha256:659691c28a0e672558b003d223f83938f254b39875ee7559d1a4a14c79173193"
  boot_command = [
    "<up><tab><spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos7.ks.cfg<return>"
  ]
  http_directory = "files"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout = "60m"
  shutdown_command = "sudo poweroff"
  # export
  format = "ova"
  output_directory = "${var.output_vmware_directory}"
}
