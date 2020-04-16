#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash
PFSERVERS_DIR=pfservers

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
test: setup global_config dot1x_eap_peap

.PHONY: setup
setup:
	./venom-wrapper.sh setup

# no teardown for this target: all things configured here have no impact
.PHONY: global_config
global_config:
	./venom-wrapper.sh $(PFSERVERS_DIR)/global_config

.PHONY: dot1x_eap_peap
dot1x_eap_peap: setup global_config
	./venom-wrapper.sh $(PFSERVERS_DIR)/dot1x_eap_peap
	./venom-wrapper.sh $(PFSERVERS_DIR)/dot1x_eap_peap/teardown

# Targets for local tests
.PHONY: dot1x_eap_peap_no_teardown
dot1x_eap_peap_no_teardown: setup global_config
	./venom-wrapper.sh $(PFSERVERS_DIR)/dot1x_eap_peap
