#==============================================================================
# Specific variables
#==============================================================================
RESULT_DIR=results
ANSIBLE_TAGS_DEV="upgrade,ci,common,venom,psonoci"
ANSIBLE_TAGS_STABLE="upgrade,common,install,venom,psonoci"
#==============================================================================
# Targets
#==============================================================================
.PHONY: all
all: pfcen7dev pfdeb9dev pfcen7stable pfdeb9stable

.PHONY: pfcen7dev
pfcen7dev:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_run_tags=$(ANSIBLE_TAGS_DEV) \
	PKR_VAR_ansible_group=vagrant_img_dev \
	PKR_VAR_pfserver=$@ \
	packer build -only="vagrant.centos-7" .

.PHONY: pfdeb9dev
pfdeb9dev:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_run_tags=$(ANSIBLE_TAGS_DEV) \
	PKR_VAR_ansible_group=vagrant_img_dev \
	PKR_VAR_pfserver=$@ \
	packer build -only="vagrant.debian-9" .

.PHONY: pfcen7stable
pfcen7stable:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_run_tags=$(ANSIBLE_TAGS_STABLE) \
	PKR_VAR_ansible_group=stable \
	PKR_VAR_pfserver=$@ \
	packer build -only="vagrant.centos-7" .

.PHONY: pfdeb9stable
pfdeb9stable:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	PKR_VAR_ansible_run_tags=$(ANSIBLE_TAGS_STABLE) \
	PKR_VAR_ansible_group=stable \
	PKR_VAR_pfserver=$@ \
	packer build -only="vagrant.debian-9" .

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

#==============================================================================
# Targets used for local tests
#==============================================================================
.PHONY: vagrant-test
vagrant-test:
	make vagrant-devel
