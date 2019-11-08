# All variables defined below and in config.mk can be considered as defaults
# for packer invocation. They can be override by:
# - environment variables (VAR=value make -e target)
# - command variables (make VAR=VALUE target)

include ../../config.mk

#==============================================================================
# Packer command line variables
#==============================================================================
ACTIVE_BUILDS = 'pfbuild-centos-7,pfbuild-stretch'

# workaround for https://github.com/hashicorp/packer/issues/7904
PARALLEL = false

# by default, we make only *one* docker tag and skip
# this docker-extra-tag post-processor
PACKER_EXTRA_ARG = '-except=docker-extra-tag'

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
	DOCKER_TAG=$(DOCKER_TAG) \
	DOCKER_EXTRA_TAG=$(DOCKER_EXTRA_TAG) \
	GOVERSION=$(GOVERSION) \
	REGISTRY=$(REGISTRY) \
	REGISTRY_USER=$(REGISTRY_USER) \
	ANSIBLE_CENTOS_GROUP=$(ANSIBLE_CENTOS_GROUP) \
	ANSIBLE_DEBIAN_GROUP=$(ANSIBLE_DEBIAN_GROUP) \
	ANSIBLE_RUBYGEMS_GROUP=$(ANSIBLE_RUBYGEMS_GROUP) \
	packer build \
	-only=$(ACTIVE_BUILDS) \
	$(PACKER_EXTRA_ARG) \
	-parallel=$(PARALLEL) $@.json

.PHONY: variables
variables:
	$(foreach var,$(.VARIABLES),$(info $(var) = $($(var))))
