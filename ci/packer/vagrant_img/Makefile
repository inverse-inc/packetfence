#==============================================================================
# Specific variables
#==============================================================================
RESULT_DIR=results
DEV_GROUP=dev
STABLE_GROUP=stable
# should be X.Y.Z (to validate vagrant-cloud checks)
BOX_VERSION=$(shell cat ../../../conf/pf-release | cut -d' ' -f 2)
ANSIBLE_FORCE_COLOR=1
#==============================================================================
# Targets
#==============================================================================
.PHONY: pfbox
pfbox:	clean
	PKR_VAR_output_directory="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(ANSIBLE_GROUP) \
	PKR_VAR_pfserver=$(BOX_NAME) \
	PKR_VAR_pf_repo=$(PF_REPO) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	packer validate -only="$(BUILD_NAME)" .

	PKR_VAR_output_directory="$(RESULT_DIR)/$(BOX_NAME)" \
	PKR_VAR_ansible_group=$(DEV_GROUP) \
	PKR_VAR_pfserver=$(BOX_NAME) \
	PKR_VAR_pf_repo=$(PF_REPO) \
	PKR_VAR_box_version=$(BOX_VERSION) \
	ANSIBLE_FORCE_COLOR=$(ANSIBLE_FORCE_COLOR) \
	packer build -only="$(BUILD_NAME)" .

# CentOS 7 builds
.PHONY: pfcen7dev
pfcen7dev:
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	PF_REPO=packetfence-devel \
	BUILD_NAME="$(DEV_GROUP).vagrant.centos-7" \
	pfbox

.PHONY: pfcen7stable
pfcen7stable:
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	PF_REPO=packetfence \
	BUILD_NAME="$(STABLE_GROUP).vagrant.centos-7" \
	pfbox

# Debian 9 builds
.PHONY: pfdeb9dev
pfdeb9dev:
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(DEV_GROUP) \
	BUILD_NAME="$(DEV_GROUP).vagrant.debian-9" \
	pfbox

.PHONY: pfdeb9stable
pfdeb9stable:
	make \
	BOX_NAME=$@ \
	ANSIBLE_GROUP=$(STABLE_GROUP) \
	BUILD_NAME="$(STABLE_GROUP).vagrant.debian-9" \
	pfbox

# Cleanup
.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)/$(BOX_NAME)

#==============================================================================
# Local tests
#==============================================================================
# dev: VAGRANT_CLOUD_TOKEN=token make -e pf*dev
# stable: BOX_VERSION=11.0.0 VAGRANT_CLOUD_TOKEN=token make -e pf*stable
