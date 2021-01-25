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
BOX_VERSION=$(shell perl -ne 'print $$1 if (m/.*?(\d+\.\d+)./)' ../../../conf/pf-release | echo "`cat -`.`date -u +%Y%m%d%H%M%S`")
VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir"
#==============================================================================
# Targets
#==============================================================================
.PHONY: pfbox
pfbox:	clean
	PKR_VAR_output_dir="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(ANSIBLE_GROUP) \
	PKR_VAR_pfserver_name=$(BOX_NAME) \
	PKR_VAR_centos_repo=$(CENTOS_REPO) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	PKR_VAR_box_description="$(BOX_DESC)" \
	packer validate -only="$(BUILD_NAME)" .

	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS=$(VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS) \
	PKR_VAR_output_dir="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(DEV_GROUP) \
	PKR_VAR_pfserver_name=$(BOX_NAME) \
	PKR_VAR_centos_repo=$(CENTOS_REPO) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	PKR_VAR_box_description="$(BOX_DESC)" \
	ANSIBLE_FORCE_COLOR=$(ANSIBLE_FORCE_COLOR) \
	packer build -only="$(BUILD_NAME)" .

# CentOS 7 builds
.PHONY: pfcen7dev
pfcen7dev:
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	CENTOS_REPO=packetfence-devel \
	BUILD_NAME="$(DEV_GROUP).vagrant.centos-7" \
	pfbox

.PHONY: pfcen7stable
pfcen7stable:
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).vagrant.centos-7" \
	pfbox

# Debian 9 builds
.PHONY: pfdeb9dev
pfdeb9dev:
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir,-ssh-hostkeys,-customize" \
	make -e \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).vagrant.debian-9" \
	pfbox

.PHONY: pfdeb9stable
pfdeb9stable:
	VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir,-ssh-hostkeys,-customize" \
	make -e \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).vagrant.debian-9" \
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
# stable: BOX_VERSION=11.0.0 VAGRANT_CLOUD_TOKEN=token make -e pf*stable
