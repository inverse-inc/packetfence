include ../../config.mk
#==============================================================================
# Specific variables
#==============================================================================
# PKR_VAR_myvar environment variable is read by Packer to set myvar in Packer
PKR_VAR_pf_version=$(PF_MINOR_RELEASE)
PKR_VAR_vm_name=PacketFence-ZEN

ANSIBLE_FORCE_COLOR=1

PF_VERSION=$(CI_COMMIT_REF_NAME)
VM_NAME=$(PKR_VAR_vm_name)
RESULT_DIR=results
PKR_ON_ERROR=cleanup

#==============================================================================
# Targets
#==============================================================================
# The build runs inside the zen-builder image, not on the runner; the
# packer configuration lives under packer/. See zen-in-docker.sh.
.PHONY: zen-deb12
zen-deb12:
	PF_VERSION="$(PF_VERSION)" \
	PKR_VAR_pf_version="$(PKR_VAR_pf_version)" \
	PKR_VAR_vm_name="$(PKR_VAR_vm_name)" \
	VM_NAME="$(VM_NAME)" \
	ANSIBLE_FORCE_COLOR="$(ANSIBLE_FORCE_COLOR)" \
	PKR_ON_ERROR="$(PKR_ON_ERROR)" \
	./zen-in-docker.sh debian-12

.PHONY: zen-el8
zen-el8:
	PF_VERSION="$(PF_VERSION)" \
	PKR_VAR_pf_version="$(PKR_VAR_pf_version)" \
	PKR_VAR_vm_name="$(PKR_VAR_vm_name)" \
	VM_NAME="$(VM_NAME)" \
	ANSIBLE_FORCE_COLOR="$(ANSIBLE_FORCE_COLOR)" \
	PKR_ON_ERROR="$(PKR_ON_ERROR)" \
	./zen-in-docker.sh el-8

.PHONY: clean_all
clean_all: clean clean_cache

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

.PHONY: clean_cache
clean_cache:
	rm -rf packer/packer_cache
