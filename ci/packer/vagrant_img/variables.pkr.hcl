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

variable box_version {
  type = string
}

variable box_description {
  type = string
}

# Path to the extracted QCOW2 from a debian/bookworm64 libvirt base box.
# The Makefile download-base-image target produces this file.
variable disk_image_url {
  type    = string
  default = "file:///tmp/packer-iso/bookworm64.img"
}

variable disk_image_checksum {
  type    = string
  default = "none"
}

# Path to the extracted QCOW2 from a debian/bullseye64 libvirt base box.
# The Makefile download-bullseye-base-image target produces this file.
variable bullseye_disk_image_url {
  type    = string
  default = "file:///tmp/packer-iso/bullseye64.img"
}

variable bullseye_disk_image_checksum {
  type    = string
  default = "none"
}

# Path to the extracted QCOW2 from a generic/rhel8 libvirt base box.
# The Makefile download-rhel8-base-image target produces this file.
variable rhel8_disk_image_url {
  type    = string
  default = "file:///tmp/packer-iso/rhel8.img"
}

variable rhel8_disk_image_checksum {
  type    = string
  default = "none"
}
