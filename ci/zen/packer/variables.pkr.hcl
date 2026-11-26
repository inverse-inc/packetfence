# Values arrive as PKR_VAR_* environment variables.
variable output_qemu_directory {
  type = string
}

variable vm_name {
  type = string
}

variable pf_version {
  type = string
}

# Where the packages come from (PF_PACKAGE_ORIGIN), and a feature branch's deployed pipeline (empty otherwise).
variable pf_package_origin {
  type = string
  default = "https://packages.packetfence.com"
}

variable pf_branches_pipeline {
  type = string
  default = ""
}

variable provisioner_dir {
  type = string
  default = "provisioners"
}

variable ansible_pfservers_group {
  type = string
  default = "pfservers"
}

