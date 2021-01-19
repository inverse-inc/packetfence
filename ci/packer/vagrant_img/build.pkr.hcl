build {
  name = "dev"
  sources = [
    "source.vagrant.centos-7",
    "source.vagrant.debian-9"
  ]

  provisioner "ansible" {
    playbook_file = "${var.provisioner_dir}/site.yml"
    host_alias = "${var.pfserver}"
    groups = [
      "${var.pfservers_group}",
      "${var.ansible_group}",
    ]
    inventory_directory = "${var.provisioner_dir}/inventory"
    galaxy_file = "${var.provisioner_dir}/requirements.yml"
    galaxy_force_install = true
    # only for ansible-galaxy command
    # we put it in a specific place where Ansible playbooks will find them
    roles_path = "${var.provisioner_dir}/playbooks/roles"
    collections_path = "${var.provisioner_dir}/playbooks/ansible_collections"
  }
  
  provisioner "shell" {
    only = ["vagrant.centos-7"]
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script = "${var.pfroot_dir}/addons/dev-helpers/centos-chroot/install-packages-from-spec.sh"
    environment_vars = [
      "PFDIR=${var.pfroot_dir}",
      "REPO=${var.pf_repo}"
    ]
  }

  provisioner "shell" {
    only = ["vagrant.debian-9"]
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script = "${var.pfroot_dir}/addons/dev-helpers/debian/install-pf-dependencies.sh"
  }
}

build {
  name = "stable"
  sources = [
    "source.vagrant.centos-7",
    "source.vagrant.debian-9"
  ]

  provisioner "ansible" {
    playbook_file = "${var.provisioner_dir}/site.yml"
    host_alias = "${var.pfserver}"
    groups = [
      "${var.pfservers_group}",
      "${var.ansible_group}",
    ]
    inventory_directory = "${var.provisioner_dir}/inventory"
    galaxy_file = "${var.provisioner_dir}/requirements.yml"
    galaxy_force_install = true
    # only for ansible-galaxy command
    # we put it in a specific place where Ansible playbooks will find them
    roles_path = "${var.provisioner_dir}/playbooks/roles"
    collections_path = "${var.provisioner_dir}/playbooks/ansible_collections"
  }
}
