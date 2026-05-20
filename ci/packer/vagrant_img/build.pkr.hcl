build {
  name = "dev"
  sources = [
    "source.vagrant.el-8",
    "source.qemu.debian-12"
  ]

  # Fix DHCP/DNS for QEMU user-mode networking.
  provisioner "shell" {
    only = ["qemu.debian-12"]
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')",
      "ip link set \"$IFACE\" up",
      "dhclient -v \"$IFACE\" || true",
      "echo 'nameserver 8.8.8.8' > /etc/resolv.conf",
    ]
  }

  provisioner "ansible" {
    playbook_file = "${var.provisioner_dir}/site.yml"
    host_alias = "${var.pfserver_name}"
    groups = [
      "${var.ansible_pfservers_group}",
      "${var.ansible_group}",
    ]
    ansible_env_vars = [
      "PF_MINOR_RELEASE=${var.pf_version}"
    ]
    extra_arguments  = ["--skip-tags", "upgrade"]
    inventory_directory = "${var.provisioner_dir}/inventory"
    galaxy_file = "${var.provisioner_dir}/requirements.yml"
    galaxy_force_install = false
    use_proxy = false
  }

  provisioner "file" {
    only = ["vagrant.el-8"]
    source = "${var.pfroot_dir}/rpm/packetfence.spec"
    destination = "${var.spec_file_path}"
  }

  provisioner "shell" {
    only = ["vagrant.el-8"]
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script = "${var.pfroot_dir}/addons/dev-helpers/centos-chroot/install-packages-from-spec.sh"
    environment_vars = [
      "SPEC=${var.spec_file_path}"
    ]
  }

  provisioner "shell" {
    only = ["qemu.debian-12"]
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script = "${var.pfroot_dir}/addons/dev-helpers/debian/install-pf-dependencies.sh"
  }

  post-processors {
    post-processor "vagrant-cloud" {
      box_tag = "inverse-inc/${var.pfserver_name}"
      version = "${var.box_version}"
      access_token = "${var.access_token}"
      version_description = "${var.box_description}"
      # temp workaround to a bug on Vagrant Cloud with Packer 1.6.6
      no_direct_upload = true
    }
  }
}

build {
  name    = "ad_dev"
  sources = ["source.qemu.bullseye-11"]

  # Fix DHCP/DNS for QEMU user-mode networking, then refresh apt cache.
  provisioner "shell" {
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')",
      "ip link set \"$IFACE\" up",
      "dhclient -v \"$IFACE\" || true",
      "echo 'nameserver 8.8.8.8' > /etc/resolv.conf",
      "apt-get update -qq",
    ]
  }

  provisioner "ansible" {
    playbook_file       = "${var.pfroot_dir}/addons/vagrant/playbooks/linux_servers/samba4ad.yml"
    host_alias          = "ad"
    groups              = ["linux_servers", "service_samba4ad"]
    inventory_directory = "${var.pfroot_dir}/addons/vagrant/inventory"
    extra_arguments = [
      "--extra-vars", "samba4ad__mgmt_ip=10.0.2.15",
      "--skip-tags",  "upgrade",
    ]
    galaxy_force_install = false
    use_proxy            = false
  }

  post-processors {
    post-processor "vagrant" {
      output              = "${var.output_dir}/${var.pfserver_name}-{{.Provider}}.box"
      keep_input_artifact = false
    }
  }
}

build {
  name = "stable"
  sources = [
    "source.vagrant.el-8",
    "source.qemu.debian-12"
  ]

  provisioner "shell" {
    only = ["qemu.debian-12"]
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')",
      "ip link set \"$IFACE\" up",
      "dhclient -v \"$IFACE\" || true",
      "echo 'nameserver 8.8.8.8' > /etc/resolv.conf",
    ]
  }

  provisioner "ansible" {
    playbook_file = "${var.provisioner_dir}/site.yml"
    host_alias = "${var.pfserver_name}"
    groups = [
      "${var.ansible_pfservers_group}",
      "${var.ansible_group}",
    ]
    ansible_env_vars = [
      "PF_MINOR_RELEASE=${var.pf_version}"
    ]
    extra_arguments  = ["--skip-tags", "upgrade"]
    inventory_directory = "${var.provisioner_dir}/inventory"
    galaxy_file = "${var.provisioner_dir}/requirements.yml"
    galaxy_force_install = false
    use_proxy = false
  }

  post-processors {
    post-processor "vagrant-cloud" {
      box_tag = "inverse-inc/${var.pfserver_name}"
      version = "${var.box_version}"
      access_token = "${var.access_token}"
      version_description = "${var.box_description}"
      # temp workaround to a bug on Vagrant Cloud with Packer 1.6.6
      no_direct_upload = true
    }
  }
}
