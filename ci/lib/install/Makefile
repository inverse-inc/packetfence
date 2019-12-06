include ../../../config.mk

#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

# Defaults settings for below targets
CI_COMMIT_TAG=vX.Y.Z

#==============================================================================
# Targets
#==============================================================================


# Using following targets requires artifact of a "pages" stage
# it means a "public" dir unzipped in PF root

.PHONY: all
all: install-pfcen7dev-dev install-pfdeb9dev-dev install-pfcen7dev-release install-pfdeb9dev-release

.PHONY: install-dev
install-dev:
	VAGRANT_BOX=$(VAGRANT_BOX) \
	./manage-vagrant-vm.sh setup

.PHONY: install-release
install-release:
	CI_COMMIT_TAG=$(CI_COMMIT_TAG) \
	VAGRANT_BOX=$(VAGRANT_BOX) \
	./manage-vagrant-vm.sh setup

.PHONY: install-pfcen7dev-dev
install-pfcen7dev-dev:
	make VAGRANT_BOX=pfcen7dev install-dev

.PHONY: install-pfdeb9dev-dev
install-pfdeb9dev-dev:
	make VAGRANT_BOX=pfdeb9dev install-dev

.PHONY: install-pfcen7dev-release
install-pfcen7dev-release:
	make VAGRANT_BOX=pfcen7dev install-release

.PHONY: install-pfdeb9dev-release
install-pfdeb9dev-release:
	make VAGRANT_BOX=pfdeb9dev install-release

.PHONY: clean
clean:
	./manage-vagrant-vm.sh teardown
