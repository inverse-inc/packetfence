build {
  name = "dev"
  sources = [
    "source.qemu.el-8",
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

  # Same fix for EL 8 — generic/rhel8 ships NetworkManager rather than
  # isc-dhcp-client, so fall back to nmcli when dhclient is absent.
  provisioner "shell" {
    only = ["qemu.el-8"]
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')",
      "ip link set \"$IFACE\" up",
      "if command -v dhclient >/dev/null 2>&1; then dhclient -v \"$IFACE\" || true; elif command -v nmcli >/dev/null 2>&1; then nmcli device connect \"$IFACE\" || true; fi",
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
    only = ["qemu.el-8"]
    source = "${var.pfroot_dir}/rpm/packetfence.spec"
    destination = "${var.spec_file_path}"
  }

  provisioner "shell" {
    only = ["qemu.el-8"]
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

  # Ship the box unregistered: the build-time RHEL subscription goes stale once
  # this build's consumer is reaped, leaving published boxes unable to reach
  # entitled repos. Runtime provisioning re-registers per dev/CI.
  provisioner "shell" {
    only = ["qemu.el-8"]
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "subscription-manager unregister || true",
      "subscription-manager clean || true",
    ]
  }

  # Local .box output picked up by upload-to-linode.sh (Linode Object Storage
  # replaced Vagrant Cloud for distribution).
  post-processors {
    post-processor "vagrant" {
      output              = "${var.output_dir}/${var.pfserver_name}-{{.Provider}}.box"
      keep_input_artifact = false
    }
  }
}

build {
  name    = "ad_dev"
  sources = ["source.qemu.bullseye-11"]

  # Fix DHCP/DNS for QEMU user-mode networking, then refresh apt cache.
  # resolv.conf is made immutable so reboots during Ansible provisioning
  # don't lose DNS (dhclient at boot would overwrite it with QEMU's 10.0.2.3).
  provisioner "shell" {
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')",
      "ip link set \"$IFACE\" up",
      "dhclient -v \"$IFACE\" || true",
      "rm -f /etc/resolv.conf",
      "echo 'nameserver 8.8.8.8' > /etc/resolv.conf",
      "chattr +i /etc/resolv.conf",
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
  name    = "node_box"
  sources = ["source.qemu.bullseye-11"]

  # Fix DHCP/DNS for QEMU user-mode networking before Ansible runs.
  provisioner "shell" {
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')",
      "ip link set \"$IFACE\" up",
      "dhclient -v \"$IFACE\" || true",
      "echo 'nameserver 8.8.8.8' > /etc/resolv.conf",
    ]
  }

  # Run the node pre-prov against the build host (joined to both groups);
  # --extra-vars drops the per-pipeline PPA + packetfence-test (see bake.yml).
  provisioner "ansible" {
    playbook_file        = "${var.pfroot_dir}/addons/vagrant/playbooks/nodes/box/bake.yml"
    host_alias           = "${var.pfserver_name}"
    groups               = ["nodes", "wireless"]
    inventory_directory  = "${var.pfroot_dir}/addons/vagrant/inventory"
    galaxy_file          = "${var.pfroot_dir}/addons/vagrant/requirements.yml"
    galaxy_force_install = true
    ansible_env_vars     = ["PF_MINOR_RELEASE=${var.pf_version}"]
    extra_arguments = [
      "--skip-tags", "upgrade",
      "--extra-vars", "gitlab_buildpkg_tools__ppa_enabled=false",
      "--extra-vars", "{\"gitlab_buildpkg_tools__deb_pkgs\":[\"wpasupplicant\",\"sscep\",\"rsync\"]}",
    ]
    use_proxy = false
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
    "source.qemu.el-8",
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

  provisioner "shell" {
    only = ["qemu.el-8"]
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')",
      "ip link set \"$IFACE\" up",
      "if command -v dhclient >/dev/null 2>&1; then dhclient -v \"$IFACE\" || true; elif command -v nmcli >/dev/null 2>&1; then nmcli device connect \"$IFACE\" || true; fi",
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

  # Ship the box unregistered: the build-time RHEL subscription goes stale once
  # this build's consumer is reaped, leaving published boxes unable to reach
  # entitled repos. Runtime provisioning re-registers per dev/CI.
  provisioner "shell" {
    only = ["qemu.el-8"]
    execute_command = "echo 'vagrant' | sudo -S -E bash '{{.Path}}'"
    inline = [
      "set -eux",
      "subscription-manager unregister || true",
      "subscription-manager clean || true",
    ]
  }

  # Local .box output picked up by upload-to-linode.sh (Linode Object Storage
  # replaced Vagrant Cloud for distribution).
  post-processors {
    post-processor "vagrant" {
      output              = "${var.output_dir}/${var.pfserver_name}-{{.Provider}}.box"
      keep_input_artifact = false
    }
  }
}
