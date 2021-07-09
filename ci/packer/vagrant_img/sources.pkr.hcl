# Vagrant EL 8 builds
source "vagrant" "el-8" {
  communicator = "ssh"
  source_path = "generic/rhel8"
  box_version = "3.2.24"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
}

# Vagrant Debian 11 builds
source "vagrant" "debian-11" {
  communicator = "ssh"
  source_path = "debian/bullseye64"
  box_version = "11.20210409.1"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
}
