include ../../config.mk

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: build_docker_pfbuild_img build_docker_cpanbuild_img

.PHONY: build_docker_pfbuild_img
build_docker_pfbuild_img:
	GOVERSION=$(GOVERSION) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) ./packer-wrapper.sh

.PHONY: build_docker_cpanbuild_img
build_docker_cpanbuild_img:
	GOVERSION=$(GOVERSION) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) \
	PACKER_TEMPLATE=cpanbuild.json ./packer-wrapper.sh
