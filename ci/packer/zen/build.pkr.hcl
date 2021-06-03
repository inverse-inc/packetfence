build {
  sources = [
    "source.virtualbox-iso.centos-7",
    "source.vmware-iso.centos-7"
  ]

  provisioner "file" {
    source = "files/rc.local"
    destination = "/tmp/rc.local"
  }

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    inline = [ "cp /tmp/rc.local /etc/rc.d/rc.local" ]
  }

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script = "scripts/install-pf.sh"
    environment_vars = [
      "PFVERSION=${var.pf_version}",
      "PFREPO=${var.pf_repo}",
      "PFPACKAGE=${var.pf_package}",
      "PFRELEASE_PKG=${var.pf_release_pkg}"
    ]
  }
}
