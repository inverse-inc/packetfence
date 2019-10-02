include ../../config.mk
ACTIVE_BUILDS = 'pfbuild-centos-7,pfbuild-stretch'

.PHONY: all
all: buildpkg

.PHONY: buildpkg
buildpkg:
	packer validate $@.json
	DOCKER_TAG=$(DOCKER_TAG) GOVERSION=$(GOVERSION) packer build -only=$(ACTIVE_BUILDS) $@.json

.PHONY: variables
variables:
	$(foreach var,$(.VARIABLES),$(info $(var) = $($(var))))
