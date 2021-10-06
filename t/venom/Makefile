include ../../config.mk
#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash
PFSERVERS_DIR=pfservers
CI_PIPELINE_ID=123456789

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

halt:
	PF_VM_NAME=$(PF_VM_NAME) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	./test-wrapper.sh halt

clean:
	./test-wrapper.sh teardown

unit_tests_el8:
	make \
	PF_VM_NAME=pfel8dev \
	SCENARIOS_TO_RUN=unit_tests \
	$(MAKE_TARGET)

configurator_el8:
	make \
	PF_VM_NAME=pfel8dev \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

configurator_deb11:
	make \
	PF_VM_NAME=pfdeb11dev \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

dot1x_eap_peap_el8:
	make \
	PF_VM_NAME=pfel8dev \
	INT_TEST_VM_NAMES="ad switch01 node01" \
	SCENARIOS_TO_RUN=dot1x_eap_peap \
	$(MAKE_TARGET)

dot1x_eap_peap_deb11:
	make \
	PF_VM_NAME=pfdeb11dev \
	INT_TEST_VM_NAMES="ad switch01 node01" \
	SCENARIOS_TO_RUN=dot1x_eap_peap \
	$(MAKE_TARGET)

mac_auth_el8:
	make \
	PF_VM_NAME=pfel8dev \
	INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=mac_auth \
	$(MAKE_TARGET)

mac_auth_deb11:
	make \
	PF_VM_NAME=pfdeb11dev \
	INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=mac_auth \
	$(MAKE_TARGET)

#==============================================================================
# Targets for local tests
#==============================================================================
# No clean
unit_tests_el8_w:
	make \
	PF_VM_NAME=pfel8dev \
	SCENARIOS_TO_RUN=unit_tests \
	$(MAKE_TARGET)

