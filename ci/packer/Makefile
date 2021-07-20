include ../../config.mk

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: build_img_docker_pfbuild build_img_docker_cpanbuild

.PHONY: build_img_docker_pfbuild
build_img_docker_pfbuild:
	GOVERSION=$(GOVERSION) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) ./packer-wrapper.sh

.PHONY: build_img_docker_cpanbuild
build_img_docker_cpanbuild:
	GOVERSION=$(GOVERSION) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) \
	PACKER_TEMPLATE=cpanbuild.json ./packer-wrapper.sh
