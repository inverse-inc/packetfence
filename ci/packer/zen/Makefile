include ../../../config.mk
#==============================================================================
# Specific variables
#==============================================================================
# PKR_VAR_myvar environment variable is read by Packer to set myvar in Packer
PKR_VAR_pf_version=$(PF_MINOR_RELEASE)
PKR_VAR_vm_name=PacketFence-ZEN
PKR_VAR_output_vbox_directory=$(RESULT_DIR)/virtualbox
PKR_VAR_output_vmware_directory=$(RESULT_DIR)/vmware

PF_VERSION=$(CI_COMMIT_REF_NAME)
VM_NAME=$(PKR_VAR_vm_name)
RESULT_DIR=results

#==============================================================================
# Targets
#==============================================================================
.PHONY: zen
zen:
	PKR_VAR_pf_version=$(PKR_VAR_pf_version) \
	PKR_VAR_vm_name=$(PKR_VAR_vm_name) \
	PKR_VAR_output_vbox_directory=$(PKR_VAR_output_vbox_directory) \
	PKR_VAR_output_vmware_directory=$(PKR_VAR_output_vmware_directory) \
	packer build -only="virtualbox-iso.*" .
	PF_VERSION=$(PF_VERSION) \
	VBOX_RESULT_DIR=$(PKR_VAR_output_vbox_directory) \
	VMWARE_RESULT_DIR=$(PKR_VAR_output_vmware_directory) \
	VM_NAME=$(VM_NAME) \
	./build-and-upload.sh

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

.PHONY: clean_cache
clean_cache:
	rm -rf packer_cache

.PHONY: zen-release
zen-release:
	make \
	PKR_VAR_pf_repo=packetfence \
	PKR_VAR_pf_package=packetfence \
	PKR_VAR_pf_release_pkg=packetfence-release-$(PF_MINOR_RELEASE).el8.noarch.rpm \
	zen

.PHONY: zen-devel
zen-devel:
	make \
	PKR_VAR_pf_repo=packetfence \
	PKR_VAR_pf_package=packetfence \
	PKR_VAR_pf_release_pkg=packetfence-release-devel.el8.noarch.rpm \
	zen \

#==============================================================================
# Targets used for local tests
#==============================================================================
.PHONY: zen-test
zen-test:
	make \
	zen-devel
