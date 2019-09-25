SHELL = /bin/sh
DOCKER_TAG = latest
INACTIVE_BUILDS = 'pfbuild-buster'

.PHONY: all
all: buildpkg

.PHONY: buildpkg
buildpkg:
	packer validate $@.json
	packer build -var 'image_tag=$(DOCKER_TAG)' -except=$(INACTIVE_BUILDS) $@.json

.PHONY: variables
variables:
	@echo SHELL: $(SHELL)
