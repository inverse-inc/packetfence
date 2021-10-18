include ../../../config.mk

#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash
CI_PIPELINE_ID=123456789
#==============================================================================
# Targets
#==============================================================================


# Using following targets requires artifact of a "pages" stage
# it means a "public" dir unzipped in PF root

.PHONY: all
all: test-pfel8dev-dev test-pfdeb11dev-dev test-pfel8dev-release test-pfdeb11dev-release

### Targets used in pipeline
.PHONY: test
test: clean
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) ./vagrant-wrapper.sh run

.PHONY: halt
halt:
	./vagrant-wrapper.sh halt

.PHONY: clean
clean:
	./vagrant-wrapper.sh teardown

.PHONY: delete
delete:
	./vagrant-wrapper.sh delete

### Targets used for local tests
# test
.PHONY: test-pfel8dev-dev
test-pfel8dev-dev:
	make PF_VM_NAME=pfel8dev \
	PERL_UNIT_TESTS=yes \
	GOLANG_UNIT_TESTS=yes \
	test

.PHONY: test-pfdeb11dev-dev
test-pfdeb11dev-dev:
	make PF_VM_NAME=pfdeb11dev \
	PERL_UNIT_TESTS=no \
	GOLANG_UNIT_TESTS=yes \
	test

.PHONY: test-pfel8dev-release
test-pfel8dev-release: get-public
	make PF_VM_NAME=pfel8dev \
	CI_COMMIT_TAG=vX.Y.Z \
	test

.PHONY: test-pfdeb11dev-release
test-pfdeb11dev-release:
	make PF_VM_NAME=pfdeb11dev \
	CI_COMMIT_TAG=vX.Y.Z \
	test

.PHONY: test-int-pfel8dev-dev
test-int-pfel8dev-dev:
	make PF_VM_NAME=pfel8dev \
	INT_TEST_VM_NAMES='ad switch01 node01 wireless01' \
	PERL_UNIT_TESTS=yes \
	GOLANG_UNIT_TESTS=yes \
	INTEGRATION_TESTS=yes \
	test

.PHONY: test-int-pfdeb11dev-dev
test-int-pfdeb11dev-dev:
	make PF_VM_NAME=pfdeb11dev \
	INT_TEST_VM_NAMES='ad switch01 node01 wireless01' \
	PERL_UNIT_TESTS=no \
	GOLANG_UNIT_TESTS=yes \
	INTEGRATION_TESTS=yes \
	test

.PHONY: test-int-dev
test-int-dev: PF_VM_NAME=pfel8dev
test-int-dev: PERL_UNIT_TESTS=no
test-int-dev: GOLANG_UNIT_TESTS=no
test-int-dev: INTEGRATION_TESTS=yes
test-int-dev: INT_TEST_VM_NAMES=ad switch01 node01 wireless01
test-int-dev:
	make PF_VM_NAME=$(PF_VM_NAME) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	PERL_UNIT_TESTS=$(PERL_UNIT_TESTS) \
	GOLANG_UNIT_TESTS=$(GOLANG_UNIT_TESTS) \
	INTEGRATION_TESTS=$(INTEGRATION_TESTS) \
	test
