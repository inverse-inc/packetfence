#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: install test clean-pfservers

.PHONY: install
install:
	./install-venom.sh

.PHONY: test
test:
	./venom-wrapper.sh setup
	./venom-wrapper.sh pfservers/*

.PHONY: clean-pfservers
clean-pfservers:
	./venom-wrapper.sh setup
	VENOM_EXIT_FLAGS="--strict" \
	./venom-wrapper.sh pfservers/10_dot1x_eap_peap/99_teardown.yml


# Targets for local tests
.PHONY: test-config
test-config:
	./venom-wrapper.sh setup
	./venom-wrapper.sh pfservers/05_config
