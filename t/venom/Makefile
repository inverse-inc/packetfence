include ../../config.mk
#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash
PFSERVERS_DIR=pfservers
CI_PIPELINE_ID=123456789

#==============================================================================
# Tests CI or localdev
#==============================================================================
# in localdev, we don't want to clean all VM created previously
ifeq ($(CI), true)
 $(info CI environment detected)
 MAKE_TARGET=run
 DEV_ENV=dev
else
 $(info localdev environment detected)
 MAKE_TARGET=run_w_clean
 DEV_ENV=localdev
endif

#==============================================================================
# Targets
#==============================================================================
.PHONY: install run run_w_clean halt clean
install:
	./install-venom.sh

run: clean
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) \
	PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) \
	PF_VM_NAME=$(PF_VM_NAME) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	SCENARIOS_TO_RUN="$(SCENARIOS_TO_RUN)" \
	./test-wrapper.sh run

run_w_clean:
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) \
	PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) \
	PF_VM_NAME=$(PF_VM_NAME) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	SCENARIOS_TO_RUN="$(SCENARIOS_TO_RUN)" \
	./test-wrapper.sh run

# to only run tests
run_tests:
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) \
	PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) \
	PF_VM_NAME=$(PF_VM_NAME) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	SCENARIOS_TO_RUN="$(SCENARIOS_TO_RUN)" \
	./test-wrapper.sh run_tests

halt:
	PF_VM_NAME=$(PF_VM_NAME) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	./test-wrapper.sh halt

clean:
	./test-wrapper.sh teardown

unit_tests_el8:
	make \
	PF_VM_NAME=pfel8$(DEV_ENV) \
	SCENARIOS_TO_RUN=unit_tests \
	$(MAKE_TARGET)

configurator_el8:
	make \
	PF_VM_NAME=pfel8$(DEV_ENV) \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

configurator_deb11:
	make \
	PF_VM_NAME=pfdeb11$(DEV_ENV) \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

dot1x_eap_peap_el8:
	make \
	PF_VM_NAME=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=dot1x_eap_peap \
	$(MAKE_TARGET)

dot1x_eap_peap_deb11:
	make \
	PF_VM_NAME=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=dot1x_eap_peap \
	$(MAKE_TARGET)

mac_auth_el8:
	make \
	PF_VM_NAME=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=mac_auth \
	$(MAKE_TARGET)

mac_auth_deb11:
	make \
	PF_VM_NAME=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=mac_auth \
	$(MAKE_TARGET)

dot1x_eap_tls_el8:
	make \
	PF_VM_NAME=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=dot1x_eap_tls \
	$(MAKE_TARGET)

dot1x_eap_tls_deb11:
	make \
	PF_VM_NAME=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=dot1x_eap_tls \
	$(MAKE_TARGET)

example_el8:
	make \
	PF_VM_NAME=pfel8$(DEV_ENV) \
	# if you want to start additional VMs
	#INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=example \
	$(MAKE_TARGET)

fingerbank_invalid_db_deb11:
	make \
	PF_VM_NAME=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=fingerbank_invalid_db \
	$(MAKE_TARGET)

example_deb11:
	make \
	PF_VM_NAME=pfdeb11$(DEV_ENV) \
	# if you want to start additional VMs
	#INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=example \
	$(MAKE_TARGET)

