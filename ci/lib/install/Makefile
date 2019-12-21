include ../../../config.mk

#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================


# Using following targets requires artifact of a "pages" stage
# it means a "public" dir unzipped in PF root

.PHONY: all
all: install-pfcen7dev-dev install-pfdeb9dev-dev install-pfcen7dev-release install-pfdeb9dev-release

### Targets used in pipeline
.PHONY: install
install:
	CI_COMMIT_TAG=$(CI_COMMIT_TAG) \
	VM_NAME=$(VM_NAME) \
	./manage-vagrant-vm.sh setup

.PHONY: clean
clean:
	VM_NAME=$(VM_NAME) \
	./manage-vagrant-vm.sh teardown

### Targets used for local tests
# install
.PHONY: install-pfcen7dev-dev
install-pfcen7dev-dev:
	make VM_NAME=pfcen7dev install-dev

.PHONY: install-pfdeb9dev-dev
install-pfdeb9dev-dev:
	make VM_NAME=pfdeb9dev install-dev

.PHONY: install-pfcen7dev-release
install-pfcen7dev-release:
	make VM_NAME=pfcen7dev install-release

.PHONY: install-pfdeb9dev-release
install-pfdeb9dev-release:
	make VM_NAME=pfdeb9dev install-release


