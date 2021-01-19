# We only declare variables without defaults
# defaults are in Makefile
variable output_directory {
  type = string
}

variable provisioner_dir {
  type = string
  default = "provisioners"
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

# variable ansible_dir {
#   type = string
#   default = "${var.pf_root}/addons/vagrant"
# }
