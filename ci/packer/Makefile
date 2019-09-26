SHELL = /bin/sh
DOCKER_TAG = latest
ACTIVE_BUILDS= 'pfbuild-centos-7,pfbuild-stretch'

.PHONY: all
all: buildpkg

.PHONY: buildpkg
buildpkg:
	packer validate $@.json
	packer build -var 'image_tag=$(DOCKER_TAG)' -only=$(ACTIVE_BUILDS) $@.json

.PHONY: variables
variables:
	@echo SHELL: $(SHELL)
