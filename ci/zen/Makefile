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
# Built from the deployed packages: debian/X.Y, or a feature branch's branches/X.Y/<pipeline>/ (DEPLOY_PKG=yes).
PF_PACKAGE_ORIGIN ?= https://packages.packetfence.com
ZEN_REPO = $(PF_PACKAGE_ORIGIN)/downloads/PacketFence/debian/$(if $(PF_BRANCHES_PIPELINE),branches/$(PF_MINOR_RELEASE)/$(PF_BRANCHES_PIPELINE),$(PF_MINOR_RELEASE))

.PHONY: zen-deb12
zen-deb12:
	@curl -fsS -o /dev/null "$(ZEN_REPO)/dists/bookworm/InRelease" || { echo "$(ZEN_REPO) is not deployed; Zen is built from the deployed packages$(if $(PF_BRANCHES_PIPELINE),: run this feature branch with DEPLOY_PKG=yes)" >&2; exit 1; }
	PF_VERSION="$(PF_VERSION)" \
	PKR_VAR_pf_version="$(PKR_VAR_pf_version)" \
	PKR_VAR_pf_package_origin="$(PF_PACKAGE_ORIGIN)" \
	PKR_VAR_pf_branches_pipeline="$(PF_BRANCHES_PIPELINE)" \
	PKR_VAR_vm_name="$(PKR_VAR_vm_name)" \
	VM_NAME="$(VM_NAME)" \
	ANSIBLE_FORCE_COLOR="$(ANSIBLE_FORCE_COLOR)" \
	PKR_ON_ERROR="$(PKR_ON_ERROR)" \
	./zen-in-docker.sh debian-12

.PHONY: clean_all
clean_all: clean_container clean clean_cache

# kill a build container orphaned by a job timeout or cancel
.PHONY: clean_container
clean_container:
	-docker rm -f zen-build-debian-12 2>/dev/null

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

.PHONY: clean_cache
clean_cache:
	rm -rf packer/packer_cache
