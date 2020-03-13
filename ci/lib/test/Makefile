include ../../../config.mk

#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash
PERL_UNIT_TESTS=yes
GOLANG_UNIT_TESTS=yes
INTEGRATION_TESTS=yes

#==============================================================================
# Targets
#==============================================================================


# Using following targets requires artifact of a "pages" stage
# it means a "public" dir unzipped in PF root

.PHONY: all
all: test-pfcen7dev-dev test-pfdeb9dev-dev test-pfcen7dev-release test-pfdeb9dev-release

### Targets used in pipeline
.PHONY: test
#test: clean
test:
	CI_COMMIT_TAG=$(CI_COMMIT_TAG) \
	VM_NAMES="$(VM_NAMES)" \
	PERL_UNIT_TESTS=$(PERL_UNIT_TESTS) \
	GOLANG_UNIT_TESTS=$(GOLANG_UNIT_TESTS) \
	./manage-vagrant-vm.sh setup
	INTEGRATION_TESTS=$(INTEGRATION_TESTS) \
	VM_NAMES="$(VM_NAMES)" \
	./manage-vagrant-vm.sh run $(firstword "$(VM_NAMES)")

.PHONY: clean
clean:
	VM_NAMES="$(VM_NAMES)" \
	./manage-vagrant-vm.sh teardown

### Targets used for local tests
# test
.PHONY: test-pfcen7dev-dev
test-pfcen7dev-dev:
	make VM_NAMES=pfcen7dev test

.PHONY: test-pfdeb9dev-dev
test-pfdeb9dev-dev:
	make VM_NAMES=pfdeb9dev \
	PERL_UNIT_TESTS=no \
	test

.PHONY: test-pfcen7dev-release
test-pfcen7dev-release:
	make VM_NAMES=pfcen7dev CI_COMMIT_TAG=vX.Y.Z test

.PHONY: test-pfdeb9dev-release
test-pfdeb9dev-release:
	make CI_COMMIT_TAG=vX.Y.Z \
	VM_NAMES=pfdeb9dev \
	PERL_UNIT_TESTS=no \
	test


