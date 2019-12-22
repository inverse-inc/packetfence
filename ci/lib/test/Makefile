include ../../../config.mk

#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash
PERL_UNIT_TESTS=yes
GOLANG_UNIT_TESTS=yes

#==============================================================================
# Targets
#==============================================================================


# Using following targets requires artifact of a "pages" stage
# it means a "public" dir unzipped in PF root

.PHONY: all
all: test-pfcen7dev-dev test-pfdeb9dev-dev test-pfcen7dev-release test-pfdeb9dev-release

### Targets used in pipeline
.PHONY: test
test: clean
	CI_COMMIT_TAG=$(CI_COMMIT_TAG) \
	VM_NAME=$(VM_NAME) \
	PERL_UNIT_TESTS=$(PERL_UNIT_TESTS) \
	GOLANG_UNIT_TESTS=$(GOLANG_UNIT_TESTS) \
	./manage-vagrant-vm.sh setup

.PHONY: clean
clean:
	VM_NAME=$(VM_NAME) \
	./manage-vagrant-vm.sh teardown

### Targets used for local tests
# test
.PHONY: test-pfcen7dev-dev
test-pfcen7dev-dev:
	make VM_NAME=pfcen7dev test

.PHONY: test-pfdeb9dev-dev
test-pfdeb9dev-dev:
	make VM_NAME=pfdeb9dev \
	PERL_UNIT_TESTS=no \
	test

.PHONY: test-pfcen7dev-release
test-pfcen7dev-release:
	make VM_NAME=pfcen7dev CI_COMMIT_TAG=vX.Y.Z test

.PHONY: test-pfdeb9dev-release
test-pfdeb9dev-release:
	make CI_COMMIT_TAG=vX.Y.Z \
	VM_NAME=pfdeb9dev \
	PERL_UNIT_TESTS=no \
	test


