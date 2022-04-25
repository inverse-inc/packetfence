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
else
 $(info localdev environment detected)
 DEV_ENV=localdev
endif

#==============================================================================
# Targets
#==============================================================================
.PHONY: run_kaniko

run_kaniko:
	docker pull gcr.io/kaniko-project/executor:debug
	docker container run --entrypoint '/busybox/sh' --rm --name "kaniko" --volume="$(SRC_ROOT_DIR)":/workspace -it gcr.io/kaniko-project/executor:debug

### Targets for localdev
DOCKERFILE_DIRS = $(shell find -type f -name "Dockerfile" -printf "%P\n")
CONTAINER_IMAGES = $(subst /Dockerfile,,$(DOCKERFILE_DIRS))

.PHONY: $(CONTAINER_IMAGES)

# KNK_REGISTRY_USER and KNK_REGISTRY_PASSWORD values
# are taken from environment
$(CONTAINER_IMAGES):
	docker container run --entrypoint '/busybox/sh' \
			--rm --name "$@_build" \
			-e "CI_PROJECT_DIR=/workspace" \
			-e "IMAGE_NAME=$@" \
			-e "IMAGE_TAGS=$(DEV_ENV)_$(KNK_REGISTRY_USER)" \
			-e "KNK_REGISTRY=$(KNK_REGISTRY)" \
			-e "KNK_REGISTRY_URL=$(KNK_REGISTRY_URL)" \
			-e "KNK_REGISTRY_USER" -e "KNK_REGISTRY_PASSWORD" \
			--volume="$(SRC_ROOT_DIR)":/workspace \
			-it gcr.io/kaniko-project/executor:debug
