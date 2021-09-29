# We only declare variables without defaults
# defaults are in Makefile
variable output_vbox_directory {
  type = string
}

variable output_vmware_directory {
  type = string
}

variable vm_name {
  type = string
}

variable pf_version {
  type = string
}

variable provisioner_dir {
  type = string
  default = "provisioners"
}

variable ansible_pfservers_group {
  type = string
  default = "pfservers"
}

