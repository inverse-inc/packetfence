# All variables defined below can be considered as defaults
# for packer invocation. They can be override by:
# - environment variables (VAR=value make -e target)
# - command variables (make VAR=VALUE target)

include ../../config.mk
ACTIVE_BUILDS = 'pfbuild-centos-7,pfbuild-stretch'
PARALLEL = true

.PHONY: all
all: buildpkg

.PHONY: buildpkg
buildpkg:
	packer validate $@.json
	DOCKER_TAG=$(DOCKER_TAG) \
	GOVERSION=$(GOVERSION) \
	packer build \
	-only=$(ACTIVE_BUILDS) \
	-parallel=$(PARALLEL) $@.json

.PHONY: variables
variables:
	$(foreach var,$(.VARIABLES),$(info $(var) = $($(var))))
