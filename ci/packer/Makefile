# All variables defined below and in config.mk can be considered as defaults
# for packer invocation. They can be override by:
# - environment variables (VAR=value make -e target)
# - command variables (make VAR=VALUE target)

include ../../config.mk

#==============================================================================
# Packer command line variables
#==============================================================================
ACTIVE_BUILDS = 'pfbuild-centos-7,pfbuild-centos-8,pfbuild-stretch,pfbuild-buster'

# workaround for https://github.com/hashicorp/packer/issues/7904
PARALLEL = false

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: pfbuild

# Environment variables are mentioned before 'packer build' commands to
# - display their values when running in CI (be careful with secret variables)
# - avoid passing each variable on CLI when running outside CI

.PHONY: pfbuild
pfbuild:
	packer validate $@.json
	DOCKER_TAGS=$(DOCKER_TAGS) \
	GOVERSION=$(GOVERSION) \
	REGISTRY=$(REGISTRY) \
	REGISTRY_USER=$(REGISTRY_USER) \
	ANSIBLE_FORCE_COLOR=$(ANSIBLE_FORCE_COLOR) \
	ANSIBLE_CENTOS_GROUP=$(ANSIBLE_CENTOS_GROUP) \
	ANSIBLE_DEBIAN_GROUP=$(ANSIBLE_DEBIAN_GROUP) \
	ANSIBLE_RUBYGEMS_GROUP=$(ANSIBLE_RUBYGEMS_GROUP) \
	packer build \
	-only=$(ACTIVE_BUILDS) \
	-parallel=$(PARALLEL) $@.json

.PHONY: variables
variables:
	$(foreach var,$(.VARIABLES),$(info $(var) = $($(var))))
