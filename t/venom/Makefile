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
.PHONY: install run clean
install:
	./install-venom.sh

run: #clean
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) ./test-wrapper.sh run

run_w_clean:
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) ./test-wrapper.sh run

clean:
	./test-wrapper.sh teardown


#==============================================================================
# Targets for local tests
#==============================================================================
# No clean
perl_unit_tests_el8: PF_VM_NAME=pfel8dev
perl_unit_tests_el8: SCENARIOS_TO_RUN='perl_unit_tests'
perl_unit_tests_el8:
	make \
	PF_VM_NAME=$(PF_VM_NAME) \
	SCENARIOS_TO_RUN=$(SCENARIOS_TO_RUN) \
	run_w_clean

golang_unit_tests_deb11: PF_VM_NAME=pfdeb11dev
golang_unit_tests_deb11: SCENARIOS_TO_RUN='golang_unit_tests'
golang_unit_tests_deb11:
	make \
	PF_VM_NAME=$(PF_VM_NAME) \
	SCENARIOS_TO_RUN=$(SCENARIOS_TO_RUN) \
	run_w_clean

golang_unit_tests_el8: PF_VM_NAME=pfel8dev
golang_unit_tests_el8: SCENARIOS_TO_RUN='golang_unit_tests'
golang_unit_tests_el8:
	make \
	PF_VM_NAME=$(PF_VM_NAME) \
	SCENARIOS_TO_RUN=$(SCENARIOS_TO_RUN) \
	run_w_clean
