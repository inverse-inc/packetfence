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
# debian/bullseye64 base box — used for the AD (Samba4) vagrant box build
BULLSEYE_BASE_BOX_VERSION ?= 11.20241217.1
BULLSEYE_BASE_BOX_URL ?= https://vagrantcloud.com/debian/boxes/bullseye64/versions/$(BULLSEYE_BASE_BOX_VERSION)/providers/libvirt/amd64/vagrant.box
BULLSEYE_BASE_BOX_CACHE_DIR ?= /tmp/packer-iso
BULLSEYE_BASE_BOX_FILE := $(BULLSEYE_BASE_BOX_CACHE_DIR)/bullseye64.img
# generic/rhel8 base box — downloaded once, QCOW2 extracted for packer disk_image build
RHEL8_BASE_BOX_VERSION ?= 4.3.12
RHEL8_BASE_BOX_URL ?= https://vagrantcloud.com/generic/boxes/rhel8/versions/$(RHEL8_BASE_BOX_VERSION)/providers/libvirt/amd64/vagrant.box
RHEL8_BASE_BOX_CACHE_DIR ?= /tmp/packer-iso
RHEL8_BASE_BOX_FILE := $(RHEL8_BASE_BOX_CACHE_DIR)/rhel8.img
# Vagrant insecure key — downloaded from the official Vagrant repository
VAGRANT_INSECURE_KEY_URL ?= https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant
VAGRANT_INSECURE_KEY_DIR := $(CURDIR)/provisioners/keys
VAGRANT_INSECURE_KEY_FILE := $(VAGRANT_INSECURE_KEY_DIR)/vagrant_insecure_key
#==============================================================================
# Targets
#==============================================================================
.PHONY: download-vagrant-key
download-vagrant-key:
	@if [ ! -f "$(VAGRANT_INSECURE_KEY_FILE)" ]; then \
		echo "===> Downloading Vagrant insecure private key..."; \
		mkdir -p "$(VAGRANT_INSECURE_KEY_DIR)"; \
		curl -fsSL "$(VAGRANT_INSECURE_KEY_URL)" -o "$(VAGRANT_INSECURE_KEY_FILE)"; \
		curl -fsSL "$(VAGRANT_INSECURE_KEY_URL).pub" -o "$(VAGRANT_INSECURE_KEY_FILE).pub"; \
		chmod 600 "$(VAGRANT_INSECURE_KEY_FILE)"; \
	else \
		echo "===> Vagrant insecure key already present: $(VAGRANT_INSECURE_KEY_FILE)"; \
	fi

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

.PHONY: download-bullseye-base-image
download-bullseye-base-image:
	mkdir -p $(BULLSEYE_BASE_BOX_CACHE_DIR)
	@if [ ! -f "$(BULLSEYE_BASE_BOX_FILE)" ]; then \
		echo "===> Downloading debian/bullseye64 libvirt box v$(BULLSEYE_BASE_BOX_VERSION)..."; \
		curl -fL "$(BULLSEYE_BASE_BOX_URL)" -o "$(BULLSEYE_BASE_BOX_CACHE_DIR)/bullseye64.box"; \
		echo "===> Extracting QCOW2 from box..."; \
		tar -xOf "$(BULLSEYE_BASE_BOX_CACHE_DIR)/bullseye64.box" box.img > "$(BULLSEYE_BASE_BOX_FILE)"; \
		rm -f "$(BULLSEYE_BASE_BOX_CACHE_DIR)/bullseye64.box"; \
	else \
		echo "===> Bullseye base image already cached: $(BULLSEYE_BASE_BOX_FILE)"; \
	fi

.PHONY: download-rhel8-base-image
download-rhel8-base-image:
	mkdir -p $(RHEL8_BASE_BOX_CACHE_DIR)
	@if [ ! -f "$(RHEL8_BASE_BOX_FILE)" ]; then \
		echo "===> Downloading generic/rhel8 libvirt box v$(RHEL8_BASE_BOX_VERSION)..."; \
		curl -fL "$(RHEL8_BASE_BOX_URL)" -o "$(RHEL8_BASE_BOX_CACHE_DIR)/rhel8.box"; \
		echo "===> Extracting QCOW2 from box..."; \
		tar -xOf "$(RHEL8_BASE_BOX_CACHE_DIR)/rhel8.box" box.img > "$(RHEL8_BASE_BOX_FILE)"; \
		rm -f "$(RHEL8_BASE_BOX_CACHE_DIR)/rhel8.box"; \
	else \
		echo "===> RHEL 8 base image already cached: $(RHEL8_BASE_BOX_FILE)"; \
	fi

.PHONY: pfbox
pfbox:	download-vagrant-key download-base-image clean
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

# EL 8 builds — host-side entry targets: the packer build itself runs inside
# the vagrant-build container (see vagrant-in-docker.sh).
.PHONY: pfel8dev
pfel8dev:
	BOX_NAME=$@ \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).qemu.el-8" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfel8box

.PHONY: pfel8stable
pfel8stable:
	BOX_NAME=$@ \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).qemu.el-8" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfel8box

# Debian builds — host-side entry targets: the packer build itself runs inside
# the vagrant-build container (see vagrant-in-docker.sh).
.PHONY: pfdeb12dev
pfdeb12dev:
	BOX_NAME=$@ \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).qemu.debian-12" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfbox

.PHONY: pfdeb12stable
pfdeb12stable:
	BOX_NAME=$@ \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).qemu.debian-12" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfbox

# AD (Samba4) builds — use debian/bullseye64 base image, runs in-container
.PHONY: pfadbox
pfadbox: download-vagrant-key download-bullseye-base-image clean
	PKR_VAR_output_dir="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(ANSIBLE_GROUP) \
	PKR_VAR_pfserver_name=$(BOX_NAME) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	PKR_VAR_box_description="$(BOX_DESC)" \
	PKR_VAR_pf_version=$(PF_MINOR_RELEASE) \
	PKR_VAR_bullseye_disk_image_url="file://$(BULLSEYE_BASE_BOX_FILE)" \
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
	PKR_VAR_bullseye_disk_image_url="file://$(BULLSEYE_BASE_BOX_FILE)" \
	ANSIBLE_FORCE_COLOR=$(ANSIBLE_FORCE_COLOR) \
	PACKER_LOG=$(PACKER_LOG) \
	PACKER_LOG_PATH=$(PACKER_LOG_PATH) \
	packer build -only="$(BUILD_NAME)" .

.PHONY: pfad11dev
pfad11dev:
	BOX_NAME=$@ \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=ad_dev \
	BUILD_NAME="ad_dev.qemu.bullseye-11" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfadbox

# Generic AD dev build — BOX_NAME must be provided externally (e.g. for branch builds)
.PHONY: pfad11dev_generic
pfad11dev_generic:
	$(if $(BOX_NAME),,$(error BOX_NAME is required for pfad11dev_generic))
	BOX_NAME="$(BOX_NAME)" \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=ad_dev \
	BUILD_NAME="ad_dev.qemu.bullseye-11" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfadbox

# Generic debian-12 dev build — BOX_NAME must be provided externally (e.g. for branch builds)
.PHONY: pfdebian12dev_generic
pfdebian12dev_generic:
	$(if $(BOX_NAME),,$(error BOX_NAME is required for pfdebian12dev_generic))
	BOX_NAME="$(BOX_NAME)" \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).qemu.debian-12" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfbox

# EL 8 builds — use generic/rhel8 base image, runs in-container
.PHONY: pfel8box
pfel8box: download-vagrant-key download-rhel8-base-image clean
	PKR_VAR_output_dir="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(ANSIBLE_GROUP) \
	PKR_VAR_pfserver_name=$(BOX_NAME) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	PKR_VAR_box_description="$(BOX_DESC)" \
	PKR_VAR_pf_version=$(PF_MINOR_RELEASE) \
	PKR_VAR_rhel8_disk_image_url="file://$(RHEL8_BASE_BOX_FILE)" \
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
	PKR_VAR_rhel8_disk_image_url="file://$(RHEL8_BASE_BOX_FILE)" \
	ANSIBLE_FORCE_COLOR=$(ANSIBLE_FORCE_COLOR) \
	PACKER_LOG=$(PACKER_LOG) \
	PACKER_LOG_PATH=$(PACKER_LOG_PATH) \
	packer build -only="$(BUILD_NAME)" .

# Generic EL 8 dev build — BOX_NAME must be provided externally (e.g. for branch builds)
.PHONY: pfel8dev_generic
pfel8dev_generic:
	$(if $(BOX_NAME),,$(error BOX_NAME is required for pfel8dev_generic))
	BOX_NAME="$(BOX_NAME)" \
	BOX_VERSION="$(BOX_VERSION)" \
	BOX_DESC="$(BOX_DESC)" \
	RESULT_DIR="$(RESULT_DIR)" \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).qemu.el-8" \
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="'--run $(CURDIR)/provisioners/shell/sysprep.sh'" \
	./vagrant-in-docker.sh pfel8box

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
# dev: make -e pf*dev
# stable: make -e pf*stable
# see containers/vagrant-build/README.md
