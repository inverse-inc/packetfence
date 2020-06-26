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

.PHONY: configurator
configurator:
	./venom-wrapper.sh $(PFSERVERS_DIR)/pfservers/configurator

# test is the entrypoint: all test suites should be referenced as target dependency
# if setup is a dependency to test target, putting setup as a dependency to other
# targets doesn't cause a recall
.PHONY: test
test: setup global_config dot1x_eap_peap wired_mac_auth backup_db_and_restore global_teardown

.PHONY: setup
setup:
	./venom-wrapper.sh setup

# teardown is done at end of all test suites: all things configured here have no impact
.PHONY: global_config
global_config:
	./venom-wrapper.sh $(PFSERVERS_DIR)/global_config

.PHONY: dot1x_eap_peap
dot1x_eap_peap: setup global_config
	./venom-wrapper.sh $(PFSERVERS_DIR)/dot1x_eap_peap
	./venom-wrapper.sh $(PFSERVERS_DIR)/dot1x_eap_peap/teardown

.PHONY: wired_mac_auth
wired_mac_auth: setup global_config
	./venom-wrapper.sh $(PFSERVERS_DIR)/wired_mac_auth
	./venom-wrapper.sh $(PFSERVERS_DIR)/wired_mac_auth/teardown

.PHONY: backup_db_and_restore
backup_db_and_restore: setup
	./venom-wrapper.sh $(PFSERVERS_DIR)/backup_db_and_restore
	./venom-wrapper.sh $(PFSERVERS_DIR)/backup_db_and_restore/teardown

.PHONY: global_teardown
global_teardown: setup
	./venom-wrapper.sh $(PFSERVERS_DIR)/global_teardown

# Targets for local tests
.PHONY: dot1x_eap_peap_no_teardown
dot1x_eap_peap_no_teardown: setup global_config
	./venom-wrapper.sh $(PFSERVERS_DIR)/dot1x_eap_peap

.PHONY: wired_mac_auth_no_teardown
wired_mac_auth_no_teardown: setup global_config
	./venom-wrapper.sh $(PFSERVERS_DIR)/wired_mac_auth

.PHONY: backup_db_and_restore_no_teardown
backup_db_and_restore_no_teardown: setup
	./venom-wrapper.sh $(PFSERVERS_DIR)/backup_db_and_restore
