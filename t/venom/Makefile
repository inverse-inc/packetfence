#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Targets
#==============================================================================
.PHONY: install
install:
	./install-venom.sh

# test is the entrypoint: all test suites should be referenced as target dependency
# if setup is a dependency to test target, putting setup as a dependency to other
# targets doesn't cause a recall
.PHONY: test
test: setup dot1x_eap_peap

.PHONY: setup
setup:
	./venom-wrapper.sh setup

.PHONY: dot1x_eap_peap
dot1x_eap_peap: setup
	./venom-wrapper.sh pfservers/dot1x_eap_peap
	./venom-wrapper.sh pfservers/dot1x_eap_peap/teardown

# Targets for local tests
.PHONY: dot1x_eap_peap_no_teardown
dot1x_eap_peap_no_teardown: setup
	./venom-wrapper.sh pfservers/dot1x_eap_peap
