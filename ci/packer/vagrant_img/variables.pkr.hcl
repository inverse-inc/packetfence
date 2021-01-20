# Directory
variable output_directory {
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

# Ansible variables
variable pfserver {
  type = string
}

variable pfservers_group {
  type = string
  default = "pfservers"
}

variable ansible_group {
  type = string
}

# Shell provisioning
variable pf_repo {
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
