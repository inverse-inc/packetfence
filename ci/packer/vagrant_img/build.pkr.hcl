build {
  sources = [
    "source.vagrant.centos-7",
    "source.vagrant.debian-9"
  ]
  # provisioner "shell" {
  #   execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
  #   inline = [ "cp /tmp/rc.local /etc/rc.d/rc.local" ]
  # }
}
