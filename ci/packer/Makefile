SHELL = /bin/sh
VERSION = $(shell git describe | sed s/packetfence-//)

buildpkg: buildpkg.json
	packer validate $@.json
	packer build -on-error abort -var 'image_version=$(VERSION)' $@.json

.PHONY : variables
variables:
	@echo SHELL: $(SHELL)
	@echo VERSION: $(VERSION)
