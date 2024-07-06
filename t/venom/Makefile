include ../../config.mk
#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash
PFSERVERS_DIR=pfservers

#==============================================================================
# Tests CI or localdev
#==============================================================================
# in localdev, we don't want to clean all VM created previously
ifeq ($(CI), true)
 $(info CI environment detected)
 MAKE_TARGET=run
 DEV_ENV=dev
 RESULT_DIR=$(CI_PROJECT_DIR)/results
else
 $(info localdev environment detected)
 MAKE_TARGET=run
 DEV_ENV=localdev
 RESULT_DIR=$(SRC_ROOT_DIR)/results
endif

#==============================================================================
# Targets
#==============================================================================
.PHONY: install run halt clean
install:
	./install-venom.sh

run:
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) \
	PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) \
	RESULT_DIR=$(RESULT_DIR) \
	PF_VM_NAMES="$(PF_VM_NAMES)" \
	CLUSTER_NAME="$(CLUSTER_NAME)" \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	SCENARIOS_TO_RUN="$(SCENARIOS_TO_RUN)" \
	./test-wrapper.sh run

# to only run tests
run_tests:
	CI_PIPELINE_ID=$(CI_PIPELINE_ID) \
	PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) \
	PF_VM_NAMES="$(PF_VM_NAMES)" \
	CLUSTER_NAME="$(CLUSTER_NAME)" \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	SCENARIOS_TO_RUN="$(SCENARIOS_TO_RUN)" \
	./test-wrapper.sh run_tests

halt: halt_pf clean_cache
halt_force: halt_pf_force clean_cache

halt_pf:
	PF_VM_NAMES="$(PF_VM_NAMES)" \
	CLUSTER_NAME="$(CLUSTER_NAME)" \
	RESULT_DIR=$(RESULT_DIR) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	./test-wrapper.sh halt

halt_pf_force:
	PF_VM_NAMES="$(PF_VM_NAMES)" \
	CLUSTER_NAME="$(CLUSTER_NAME)" \
	RESULT_DIR=$(RESULT_DIR) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	./test-wrapper.sh halt_force

teardown: teardown_pf clean_cache
teardown_pf:
	PF_VM_NAMES="$(PF_VM_NAMES)" \
	CLUSTER_NAME="$(CLUSTER_NAME)" \
	RESULT_DIR=$(RESULT_DIR) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	./test-wrapper.sh teardown

clean: clean_pf clean_cache

clean_pf:
	RESULT_DIR=$(RESULT_DIR) \
	./test-wrapper.sh teardown

clean_cache:
	sudo /bin/sync; echo 1 | sudo /usr/bin/tee /proc/sys/vm/drop_caches

### Pristine images
# use pristine images to install PacketFence from scratch
# with all dependencies
configurator_el8_pristine:
	make \
	PF_VM_NAMES=el8$(DEV_ENV) \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

configurator_deb11_pristine:
	make \
	PF_VM_NAMES=deb11$(DEV_ENV) \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

### End of pristine images

unit_tests_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	SCENARIOS_TO_RUN=unit_tests \
	$(MAKE_TARGET)

configurator_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

configurator_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	SCENARIOS_TO_RUN=configurator \
	$(MAKE_TARGET)

dot1x_eap_peap_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01 node03 wireless01" \
	SCENARIOS_TO_RUN=dot1x_eap_peap \
	$(MAKE_TARGET)

dot1x_eap_peap_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01 node03 wireless01" \
	SCENARIOS_TO_RUN=dot1x_eap_peap \
	$(MAKE_TARGET)

mac_auth_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=mac_auth \
	$(MAKE_TARGET)

mac_auth_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=mac_auth \
	$(MAKE_TARGET)

dot1x_eap_tls_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01" \
	SCENARIOS_TO_RUN=dot1x_eap_tls \
	$(MAKE_TARGET)

dot1x_eap_tls_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01" \
	SCENARIOS_TO_RUN=dot1x_eap_tls \
	$(MAKE_TARGET)

inline_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	SCENARIOS_TO_RUN=inline \
	$(MAKE_TARGET)

inline_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	SCENARIOS_TO_RUN=inline \
	$(MAKE_TARGET)

fingerbank_invalid_db_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="ad switch01 node01 wireless01" \
	SCENARIOS_TO_RUN=fingerbank_invalid_db \
	$(MAKE_TARGET)

external_integrations_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="linux02" \
	SCENARIOS_TO_RUN=external_integrations \
	$(MAKE_TARGET)

security_events_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=security_events \
	$(MAKE_TARGET)

cli_login_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
        SCENARIOS_TO_RUN=cli_login \
        $(MAKE_TARGET)

cli_login_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	SCENARIOS_TO_RUN=cli_login \
	$(MAKE_TARGET)

captive_portal_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=captive_portal \
	$(MAKE_TARGET)

captive_portal_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01" \
	SCENARIOS_TO_RUN=captive_portal \
	$(MAKE_TARGET)

inline_l2_and_radius_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01 node03" \

	SCENARIOS_TO_RUN=inline_l2_and_radius \
	$(MAKE_TARGET)
inline_l2_and_radius_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="switch01 node01 node03" \
	SCENARIOS_TO_RUN=inline_l2_and_radius \
	$(MAKE_TARGET)

pfappserver_configurator_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	SCENARIOS_TO_RUN=pfappserver_configurator \
	$(MAKE_TARGET)

pfappserver_configurator_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	SCENARIOS_TO_RUN=pfappserver_configurator \
	$(MAKE_TARGET)

pfappserver_configuration_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	SCENARIOS_TO_RUN=pfappserver_configuration \
	$(MAKE_TARGET)

pfappserver_configuration_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	SCENARIOS_TO_RUN=pfappserver_configuration \
	$(MAKE_TARGET)

example_el8: SCENARIOS_TO_RUN=example
example_el8:
	make \
	PF_VM_NAMES=pfel8$(DEV_ENV) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	SCENARIOS_TO_RUN="$(SCENARIOS_TO_RUN)" \
	$(MAKE_TARGET)

# can be overriden like this:
# make -C t/venom/ INT_TEST_VM_NAMES=switch01 SCENARIOS_TO_RUN=configurator example_deb11
example_deb11: SCENARIOS_TO_RUN=example
example_deb11:
	make \
	PF_VM_NAMES=pfdeb11$(DEV_ENV) \
	INT_TEST_VM_NAMES="$(INT_TEST_VM_NAMES)" \
	SCENARIOS_TO_RUN="$(SCENARIOS_TO_RUN)" \
	$(MAKE_TARGET)

test_deb11:
	make \
        PF_VM_NAMES=pfdeb11$(DEV_ENV) \
        SCENARIOS_TO_RUN=test_venom\
        $(MAKE_TARGET)

cluster_deb11:
	make \
	PF_VM_NAMES="pf1deb11$(DEV_ENV) pf2deb11$(DEV_ENV) pf3deb11$(DEV_ENV)" \
	CLUSTER_NAME="$@$(DEV_ENV)" \
	SCENARIOS_TO_RUN=cluster \
	$(MAKE_TARGET)

cluster_el8:
	make \
	PF_VM_NAMES="pf1el8$(DEV_ENV) pf2el8$(DEV_ENV) pf3el8$(DEV_ENV)" \
	CLUSTER_NAME="$@$(DEV_ENV)" \
	SCENARIOS_TO_RUN=cluster \
	$(MAKE_TARGET)

### alias to run tests on other branches
# it's a hack to simplify definition of jobs in .gitlab-ci.yml
captive_portal_deb11_branches: captive_portal_deb11
captive_portal_el8_branches: captive_portal_el8
cli_login_deb11_branches: cli_login_deb11
cli_login_el8_branches: cli_login_el8
configurator_deb11_branches: configurator_deb11
configurator_el8_branches: configurator_el8
dot1x_eap_peap_deb11_branches: dot1x_eap_peap_deb11
dot1x_eap_peap_el8_branches: dot1x_eap_peap_el8
dot1x_eap_tls_deb11_branches: dot1x_eap_tls_deb11
dot1x_eap_tls_el8_branches: dot1x_eap_tls_el8
external_integrations_deb11_branches: external_integrations_deb11
fingerbank_invalid_db_deb11_branches: fingerbank_invalid_db_deb11
inline_deb11_branches: inline_deb11
inline_el8_branches: inline_el8
mac_auth_deb11_branches: mac_auth_deb11
mac_auth_el8_branches: mac_auth_el8
security_events_deb11_branches: security_events_deb11
unit_tests_el8_branches: unit_tests_el8
pfappserver_configurator_el8_branches: pfappserver_configurator_el8
pfappserver_configurator_deb11_branches: pfappserver_configurator_deb11
pfappserver_configuration_el8_branches: pfappserver_configuration_el8
pfappserver_configuration_deb11_branches: pfappserver_configuration_deb11
