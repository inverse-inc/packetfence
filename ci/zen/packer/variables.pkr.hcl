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

variable provisioner_dir {
  type = string
  default = "provisioners"
}

variable ansible_pfservers_group {
  type = string
  default = "pfservers"
}

