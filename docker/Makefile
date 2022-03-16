include ../config.mk

#==============================================================================
# Specific variables
#==============================================================================
SHELL=/bin/bash

#==============================================================================
# Tests CI or localdev
#==============================================================================
ifeq ($(CI), true)
 $(info CI environment detected)
 DEV_ENV=dev
 RESULT_DIR=$(CI_PROJECT_DIR)/results
else
 $(info localdev environment detected)
 DEV_ENV=localdev
 CI_REGISTRY=FIXME
 CI_REGISTRY_USER=FIXME
 CI_REGISTRY_PASSWORD=FIXME
 CI_REGISTRY_IMAGE=FIXME
 CI_PROJECT_DIR=$(SRC_ROOT_DIR)
endif

#==============================================================================
# Targets
#==============================================================================
.PHONY: install build pfdebian pfgo

install:
	docker pull gcr.io/kaniko-project/executor:debug

# we expect to be inside a Kaniko image
build:
	# TODO hide this
	IMAGE_NAME="$(IMAGE_NAME)" \
	CI_REGISTRY="$(CI_REGISTRY)" \
	CI_REGISTRY_USER="$(CI_REGISTRY_USER)" \
	CI_REGISTRY_PASSWORD="$(CI_REGISTRY_PASSWORD)" \
	CI_REGISTRY_IMAGE="$(CI_REGISTRY_IMAGE)" \
	CI_PROJECT_DIR="$(CI_PROJECT_DIR)" \
	./kanikobuild

pfdebian:
	make \
	IMAGE_NAME=$@ \
	build

pfgo:
	make \
	IMAGE_NAME=$@ \
	build \
