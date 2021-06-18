include ../../config.mk

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: build_docker_img

.PHONY: build_docker_img
build_docker_img:
	GOVERSION=$(GOVERSION) PF_MINOR_RELEASE=$(PF_MINOR_RELEASE) ./packer-wrapper.sh
