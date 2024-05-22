build {
  sources = [
    "source.virtualbox-iso.debian-12",
  ]
  provisioner "ansible" {
    playbook_file = "${var.provisioner_dir}/site.yml"
    extra_arguments = ["--skip-tags", "rc-local-include-variables"]
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

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script = "${var.provisioner_dir}/shell/sysprep-packetfence.sh"
  }
}
