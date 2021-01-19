#==============================================================================
# Specific variables
#==============================================================================
RESULT_DIR=results
DEV_GROUP=dev
STABLE_GROUP=stable
#==============================================================================
# Targets
#==============================================================================
.PHONY: all
all: pfcen7dev pfdeb9dev pfcen7stable pfdeb9stable

.PHONY: pfcen7dev
pfcen7dev:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_group=$(DEV_GROUP) \
	PKR_VAR_pfserver=$@ \
	PKR_VAR_pf_repo=packetfence-devel \
	packer build -only="$(DEV_GROUP).vagrant.centos-7" .

.PHONY: pfdeb9dev
pfdeb9dev:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_group=$(DEV_GROUP) \
	PKR_VAR_pfserver=$@ \
	packer build -only="$(DEV_GROUP).vagrant.debian-9" .

.PHONY: pfcen7stable
pfcen7stable:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_group=$(STABLE_GROUP) \
	PKR_VAR_pfserver=$@ \
	packer build -only="$(STABLE_GROUP).vagrant.centos-7" .

.PHONY: pfdeb9stable
pfdeb9stable:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_group=$(STABLE_GROUP) \
	PKR_VAR_pfserver=$@ \
	packer build -only="$(STABLE_GROUP).vagrant.debian-9" .

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

#==============================================================================
# Targets used for local tests
#==============================================================================
.PHONY: vagrant-test
vagrant-test:
	make vagrant-devel
