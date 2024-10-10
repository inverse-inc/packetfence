include ../../../config.mk
#==============================================================================
# Specific variables
#==============================================================================
# PKR_VAR_myvar environment variable is read by Packer to set myvar in Packer
PKR_VAR_pf_version=$(PF_MINOR_RELEASE)
PKR_VAR_vm_name=PacketFence-ZEN
PKR_VAR_output_vbox_directory=$(RESULT_DIR)/virtualbox
PKR_VAR_output_vmware_directory=$(RESULT_DIR)/vmware

ANSIBLE_FORCE_COLOR=1

PF_VERSION=$(CI_COMMIT_REF_NAME)
VM_NAME=$(PKR_VAR_vm_name)
RESULT_DIR=results
PKR_ON_ERROR=cleanup

#==============================================================================
# Targets
#==============================================================================
.PHONY: zen
zen: zen-packer zen-build

.PHONY: zen-packer
zen-packer:
	PKR_VAR_pf_version=$(PKR_VAR_pf_version) \
	PKR_VAR_vm_name=$(PKR_VAR_vm_name) \
	PKR_VAR_output_vbox_directory=$(PKR_VAR_output_vbox_directory) \
	PKR_VAR_output_vmware_directory=$(PKR_VAR_output_vmware_directory) \
	ANSIBLE_FORCE_COLOR=$(ANSIBLE_FORCE_COLOR) \
	packer build -only="virtualbox-iso.$(BUILD_NAME)" -on-error=$(PKR_ON_ERROR) .

.PHONY: zen-build
zen-build:
	PF_VERSION=$(PF_VERSION) \
	VBOX_RESULT_DIR=$(PKR_VAR_output_vbox_directory) \
	VMWARE_RESULT_DIR=$(PKR_VAR_output_vmware_directory) \
	VM_NAME=$(VM_NAME) \
	./build-and-upload.sh

.PHONY: clean_all
clean_all: clean clean_cache

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

.PHONY: clean_cache
clean_cache:
	rm -rf packer_cache

.PHONY: zen-deb12
zen-deb12:
	make \
	BUILD_NAME=debian-12 \
	zen

.PHONY: zen-el8
zen-el8:
	make \
	BUILD_NAME=el-8 \
	zen
