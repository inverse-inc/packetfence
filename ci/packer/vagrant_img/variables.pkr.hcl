variable output_dir {
  type = string
}

variable provisioner_dir {
  type = string
  default = "provisioners"
}

variable pfroot_dir {
  type = string
  default = "../../.."
}

variable pfserver_name {
  type = string
}

variable pf_version {
  type = string
}


variable ansible_pfservers_group {
  type = string
  default = "pfservers"
}

variable ansible_group {
  type = string
}

variable spec_file_path {
  type = string
  default = "/tmp/packetfence.spec"
}

# Vagrant cloud
# only env variable which is not passed using Makefile
# to avoid a display on screen
variable access_token {
  type = string
  default = env("VAGRANT_CLOUD_TOKEN")
  sensitive = true
}

variable box_version {
  type = string
}

variable box_description {
  type = string
}

variable iso_url {
  type    = string
  default = "https://debian.uvigo.es/debian-cd/12.11.0/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"
}

variable iso_checksum {
  type    = string
  default = "sha256:30ca12a15cae6a1033e03ad59eb7f66a6d5a258dcf27acd115c2bd42d22640e8"
}
