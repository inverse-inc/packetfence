#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: install test clean

.PHONY: install
install:
	./install-venom.sh

.PHONY: test
test:
	./venom-wrapper.sh setup
	# run all test suite in each subdirectories
	./venom-wrapper.sh pfservers

.PHONY: clean
clean:
	./venom-wrapper.sh teardown


# Targets for local tests
.PHONY: test-config
test-config:
	./venom-wrapper.sh setup
	./venom-wrapper.sh pfservers/05_config
