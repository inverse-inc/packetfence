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
  default = "https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/debian-12.14.0-amd64-netinst.iso"
}

variable iso_checksum {
  type    = string
  default = "sha256:adfcbb50782af99d457467f9b38c9e0fb3b1b6e211e0202f099aa58874b3f923"
}
