#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: install test test-config

.PHONY: install
install:
	./install-venom.sh

.PHONY: test
test:
	./venom-wrapper.sh setup
	./venom-wrapper.sh pfservers/*


# Targets for local tests
.PHONY: test-config
test-config:
	./venom-wrapper.sh setup
	VENOM_EXCLUDE_FLAGS="--exclude $(PWD)/pfservers/10_dot1x_eap_peap/99_teardown.yml" \
	./venom-wrapper.sh pfservers/*
