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
  # set to empty string to allow other builds to start even if not defined
  default = ""
}

variable spec_file_path {
  type = string
  default = "/tmp/packetfence.spec"
}

# Vagrant cloud
variable access_token {
  type = string
  default = env("VAGRANT_CLOUD_TOKEN")
  sensitive = true
}

variable devel_version {
  type = string
}

variable release_version {
  type = string
  default = env("CI_COMMIT_TAG")
}
