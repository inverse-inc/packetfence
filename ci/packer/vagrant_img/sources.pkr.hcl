# Vagrant CentOS 7 builds
source "vagrant" "centos-7" {
  communicator = "ssh"
  source_path = "centos/7"
  box_version = "2004.01"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
}

# Vagrant Debian 9 builds
source "vagrant" "debian-9" {
  communicator = "ssh"
  source_path = "debian/stretch64"
  box_version = "9.12.0"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
}
