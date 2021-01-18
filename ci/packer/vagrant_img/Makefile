#==============================================================================
# Specific variables
#==============================================================================
RESULT_DIR=results

#==============================================================================
# Targets
#==============================================================================
.PHONY: vagrant
vagrant: vagrant-centos-7 vagrant-debian-9

.PHONY: vagrant-centos-7
vagrant-centos-7:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
	packer build -only="vagrant.centos-7" .

.PHONY: vagrant-debian-9
vagrant-debian-9:
	PKR_VAR_output_directory="$(RESULT_DIR)/$@" \
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
