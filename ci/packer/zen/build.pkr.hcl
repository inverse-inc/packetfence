build {
  sources = [
    "source.virtualbox-iso.debian-11",
  ]
  provisioner "ansible" {
    playbook_file = "${var.provisioner_dir}/site.yml"
    extra_arguments = ["--skip-tags='rc-local-include-variables'"]
    host_alias = "${var.vm_name}"
    groups = [
      "${var.ansible_pfservers_group}",
    ]
    ansible_env_vars = [
      "PF_MINOR_RELEASE=${var.pf_version}"
    ]
    inventory_directory = "${var.provisioner_dir}/inventory"
    galaxy_file = "${var.provisioner_dir}/requirements.yml"
    galaxy_force_install = true
    # temp
    keep_inventory_file = true
  }
}
