# All variables defined below can be considered as defaults
# for packer invocation. They can be override by:
# - environment variables (VAR=value make -e target)
# - command variables (make VAR=VALUE target)

include ../../config.mk
ACTIVE_BUILDS = 'pfbuild-centos-7,pfbuild-stretch'
# workaround for https://github.com/hashicorp/packer/issues/7904
PARALLEL = false

.PHONY: all
all: pfbuild

.PHONY: pfbuild
pfbuild:
	packer validate $@.json
	DOCKER_TAG=$(DOCKER_TAG) \
	GOVERSION=$(GOVERSION) \
	packer build \
	-only=$(ACTIVE_BUILDS) \
	-parallel=$(PARALLEL) $@.json

.PHONY: variables
variables:
	$(foreach var,$(.VARIABLES),$(info $(var) = $($(var))))
