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

variable pf_repo {
  type = string
  # set to empty string to allow debian builds to start even if not defined
  default = ""
}
