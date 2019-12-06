include ../../../config.mk

#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================


# Using following targets requires artifact of a "pages" stage
# unzipped in PF root

.PHONY: all
all: install-pfcen7dev-dev install-pfdeb9dev-dev install-pfcen7dev-release install-pfdeb9dev-release

.PHONY: install-pfcen7dev-dev
install-pfcen7dev-dev:
	VAGRANT_BOX=pfcen7dev \
	./manage-vagrant-vm.sh setup

.PHONY: install-pfdeb9dev-dev
install-pfdeb9dev-dev:
	VAGRANT_BOX=pfdeb9dev \
	./manage-vagrant-vm.sh setup

.PHONY: install-pfcen7dev-release
install-pfcen7dev-release:
	CI_COMMIT_TAG=vX.Y.Z \
	VAGRANT_BOX=pfcen7dev \
	./manage-vagrant-vm.sh setup

.PHONY: install-pfdeb9dev-release
install-pfdeb9dev-release:
	CI_COMMIT_TAG=vX.Y.Z \
	VAGRANT_BOX=pfdeb9dev \
	./manage-vagrant-vm.sh setup

.PHONY: clean
clean:
	./manage-vagrant-vm.sh teardown
