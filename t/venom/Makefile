#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: test

.PHONY: install
install:
	./install-venom.sh

.PHONY: test
test:
	./venom-wrapper.sh setup
	./venom-wrapper.sh pfservers

.PHONY: clean
clean:
	./venom-wrapper.sh teardown

