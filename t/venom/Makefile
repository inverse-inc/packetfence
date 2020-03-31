#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: install test clean

.PHONY: test
test:
	./venom-wrapper.sh setup
	./venom-wrapper.sh pfservers

.PHONY: install
install:
	./install-venom.sh


.PHONY: clean
clean:
	./venom-wrapper.sh teardown

