build {
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
    roles_path = "${var.provisioner_dir}/playbooks/roles"
    collections_path = "${var.provisioner_dir}/playbooks/ansible_collections"
  }
}
