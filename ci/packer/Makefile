SHELL = /bin/sh
DOCKER_TAG = latest
INACTIVE_BUILDS = 'pfbuild-buster'

buildpkg: buildpkg.json
	packer validate $@.json
	packer build -var 'image_tag=$(DOCKER_TAG)' -except=$(INACTIVE_BUILDS) $@.json

.PHONY : variables
variables:
	@echo SHELL: $(SHELL)
