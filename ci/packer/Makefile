include ../../config.mk

#==============================================================================
# Targets
#==============================================================================

.PHONY: all
all: build_img

.PHONY: build_img
build_img:
	GOVERSION=$(GOVERSION) ./packer-wrapper.sh
