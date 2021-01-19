# We only declare variables without defaults
# defaults are in Makefile
variable output_directory {
  type = string
}

variable pf_root {
  type = string
  default = "../../.."
}

variable pfserver {
  type = string
}

variable ansible_group {
  type = string
}

# variable ansible_dir {
#   type = string
#   default = "${var.pf_root}/addons/vagrant"
# }
