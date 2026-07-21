include ../../../config.mk
#==============================================================================
# Specific variables
#==============================================================================
### All these variables can be overriden by environment when calling with:
# VAR=value make -e target
# following values can be considered as default values
RESULT_DIR=results
DEV_GROUP=dev
STABLE_GROUP=stable
ANSIBLE_FORCE_COLOR=1
BOX_DESC='local-test'
# should follow semver X.Y.Z (to validate vagrant-cloud checks) and
# be unique at each build (see https://github.com/hashicorp/packer/issues/9492)
# generate: X.Y.UTC_DATE
# $$1 is to avoid make interpretation
BOX_VERSION=$(shell echo $(PF_MINOR_RELEASE) | echo "`cat -`.`date -u +%Y%m%d%H%M%S`")
VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS=""
VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir"
PACKER_LOG=1
# work only when PACKER_LOG value is different than 0
PACKER_LOG_PATH=/var/tmp/packer_$(shell date +%Y-%m_%d-%Hh%Mm%S.log)
#==============================================================================
# Targets
#==============================================================================
.PHONY: pfbox
pfbox:	clean
	PKR_VAR_output_dir="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(ANSIBLE_GROUP) \
	PKR_VAR_pfserver_name=$(BOX_NAME) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	PKR_VAR_box_description="$(BOX_DESC)" \
	PKR_VAR_pf_version=$(PF_MINOR_RELEASE) \
	PACKER_LOG=$(PACKER_LOG) \
	PACKER_LOG_PATH=$(PACKER_LOG_PATH) \
	packer validate -only="$(BUILD_NAME)" .

	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS=$(VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS) \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS=$(VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS) \
	PKR_VAR_output_dir="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(ANSIBLE_GROUP) \
	PKR_VAR_pfserver_name=$(BOX_NAME) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	PKR_VAR_box_description="$(BOX_DESC)" \
	PKR_VAR_pf_version=$(PF_MINOR_RELEASE) \
	ANSIBLE_FORCE_COLOR=$(ANSIBLE_FORCE_COLOR) \
	PACKER_LOG=$(PACKER_LOG) \
	PACKER_LOG_PATH=$(PACKER_LOG_PATH) \
	packer build -only="$(BUILD_NAME)" .

# EL builds
.PHONY: pfel8dev
pfel8dev:
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).vagrant.el-8" \
	pfbox

.PHONY: pfel8stable
pfel8stable:
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).vagrant.el-8" \
	pfbox

# Debian builds
.PHONY: pfdeb12dev
pfdeb12dev:
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	make -e \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).vagrant.debian-12" \
	pfbox

.PHONY: pfdeb12stable
pfdeb12stable:
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	make -e \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).vagrant.debian-12" \
	pfbox

# Cleanup
.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)/$(BOX_NAME)

.PHONY: clean_all
clean_all:
	rm -rf $(RESULT_DIR)/

#==============================================================================
# Local tests
#==============================================================================
# dev: VAGRANT_CLOUD_TOKEN=token make -e pf*dev
# stable: VAGRANT_CLOUD_TOKEN=token make -e pf*stable
