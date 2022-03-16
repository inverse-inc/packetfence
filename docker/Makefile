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

