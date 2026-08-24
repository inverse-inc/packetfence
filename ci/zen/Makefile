include ../../config.mk
# Plain KEY=value, so make can include the same file the ISO builders source.
include ../debian-version.conf
#==============================================================================
# Specific variables
#==============================================================================
# PKR_VAR_myvar environment variable is read by Packer to set myvar in Packer
PKR_VAR_pf_version=$(PF_MINOR_RELEASE)
PKR_VAR_vm_name=PacketFence-ZEN
PKR_VAR_debian_version=$(DEBIAN_VERSION)
PKR_VAR_debian_netinst_sha256=$(DEBIAN_NETINST_SHA256)

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
.PHONY: zen-deb13
zen-deb13:
	PF_VERSION="$(PF_VERSION)" \
	PKR_VAR_pf_version="$(PKR_VAR_pf_version)" \
	PKR_VAR_vm_name="$(PKR_VAR_vm_name)" \
	PKR_VAR_debian_version="$(PKR_VAR_debian_version)" \
	PKR_VAR_debian_netinst_sha256="$(PKR_VAR_debian_netinst_sha256)" \
	VM_NAME="$(VM_NAME)" \
	ANSIBLE_FORCE_COLOR="$(ANSIBLE_FORCE_COLOR)" \
	PKR_ON_ERROR="$(PKR_ON_ERROR)" \
	./zen-in-docker.sh debian-13

.PHONY: clean_all
clean_all: clean_container clean clean_cache

# kill a build container orphaned by a job timeout or cancel
.PHONY: clean_container
clean_container:
	-docker rm -f zen-build-debian-13 2>/dev/null

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

.PHONY: clean_cache
clean_cache:
	rm -rf packer/packer_cache
