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
# debian/bookworm64 base box — downloaded once, QCOW2 extracted for packer disk_image build
DEBIAN_BASE_BOX_VERSION ?= 12.20260519.1
DEBIAN_BASE_BOX_URL ?= https://vagrantcloud.com/debian/boxes/bookworm64/versions/$(DEBIAN_BASE_BOX_VERSION)/providers/libvirt/amd64/vagrant.box
DEBIAN_BASE_BOX_CACHE_DIR ?= /tmp/packer-iso
DEBIAN_BASE_BOX_FILE := $(DEBIAN_BASE_BOX_CACHE_DIR)/bookworm64.img
#==============================================================================
# Targets
#==============================================================================
.PHONY: download-base-image
download-base-image:
	mkdir -p $(DEBIAN_BASE_BOX_CACHE_DIR)
	@if [ ! -f "$(DEBIAN_BASE_BOX_FILE)" ]; then \
		echo "===> Downloading debian/bookworm64 libvirt box v$(DEBIAN_BASE_BOX_VERSION)..."; \
		curl -fL "$(DEBIAN_BASE_BOX_URL)" -o "$(DEBIAN_BASE_BOX_CACHE_DIR)/bookworm64.box"; \
		echo "===> Extracting QCOW2 from box..."; \
		tar -xOf "$(DEBIAN_BASE_BOX_CACHE_DIR)/bookworm64.box" box.img > "$(DEBIAN_BASE_BOX_FILE)"; \
		rm -f "$(DEBIAN_BASE_BOX_CACHE_DIR)/bookworm64.box"; \
	else \
		echo "===> Base image already cached: $(DEBIAN_BASE_BOX_FILE)"; \
	fi

.PHONY: pfbox
pfbox:	download-base-image clean
	PKR_VAR_output_dir="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(ANSIBLE_GROUP) \
	PKR_VAR_pfserver_name=$(BOX_NAME) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	PKR_VAR_box_description="$(BOX_DESC)" \
	PKR_VAR_pf_version=$(PF_MINOR_RELEASE) \
	PKR_VAR_disk_image_url="file://$(DEBIAN_BASE_BOX_FILE)" \
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
	PKR_VAR_disk_image_url="file://$(DEBIAN_BASE_BOX_FILE)" \
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
	BUILD_NAME="$(DEV_GROUP).qemu.debian-12" \
	pfbox

.PHONY: pfdeb12stable
pfdeb12stable:
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	make -e \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).qemu.debian-12" \
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
