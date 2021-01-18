build {
  sources = [
    "source.vagrant.centos-7",
    "source.vagrant.debian-9"
  ]

  provisioner "ansible" {
    playbook_file = "${var.pf_root}/addons/vagrant/site.yml"
    ansible_env_vars = [
      "ANSIBLE_RUN_TAGS=${var.ansible_run_tags}"
    ]
    host_alias = "${var.pfserver}"
    groups = [
      "pfservers",
      "${var.ansible_group}",
    ]
    inventory_directory = "${var.pf_root}/addons/vagrant/inventory/"
    galaxy_file = "${var.pf_root}/addons/vagrant/requirements.yml"
    galaxy_force_install = true
    roles_path = "roles"
    collections_path = "ansible_collections"
  }
}
