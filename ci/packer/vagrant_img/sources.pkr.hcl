# Vagrant CentOS 7 builds
source "vagrant" "centos-7" {
  communicator = "ssh"
  source_path = "centos/7"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
}

# Vagrant Debian 9 builds
source "vagrant" "debian-9" {
  communicator = "ssh"
  source_path = "debian/stretch64"
  provider = "libvirt"
  output_dir = "${var.output_dir}"
  template = "templates/vagrantfile_template"
}
