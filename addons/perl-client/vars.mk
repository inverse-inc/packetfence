### Fingerbank variables
# source dirs
# hack to get directory of config.mk from any Makefile in source tree
# even if make is called with -C
SRC_ROOT_DIR = $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SRC_RPMDIR = $(SRC_ROOT_DIR)/rpm
SRC_DEBDIR = $(SRC_ROOT_DIR)/debian
SRC_TESTDIR = $(SRC_ROOT_DIR)/t
SRC_VAGRANTDIR = $(SRC_ROOT_DIR)/vagrant
SRC_CIDIR = $(SRC_ROOT_DIR)/ci
SRC_RESULTDIR = $(SRC_ROOT_DIR)/result

FB_CONSTANT_PATH=$(shell readlink -e $(SRC_ROOT_DIR)/lib/fingerbank/Constant.pm)

# FB_VERSION equals X.Y.Z
FB_VERSION=$(shell grep "^Readonly::Scalar our \$$VERSION" $(FB_CONSTANT_PATH) | awk -F '"' '{ print $$2}')

API_KEY = ${FINGERBANK_API_KEY}
UPSTREAM_DB_URL = https://api.fingerbank.org/api/v2/download/db


# all directories and files to include in Fingerbank package
# $(SRC_ROOT_DIR)/* to exclude SRC_ROOT_DIR himself
files_to_include = $(shell find $(SRC_ROOT_DIR)/* \
	-maxdepth 0 \
	-not -path "$(SRC_CIDIR)" \
	-not -path "$(SRC_DEBDIR)" \
	-not -path "$(SRC_ROOT_DIR)/fingerbank-$(FB_VERSION)" \
	-not -path "$(SRC_ROOT_DIR)/.git" \
	-not -path "$(SRC_ROOT_DIR)/.github" \
	-not -path "$(SRC_RESULTDIR)" \
	-not -path "$(SRC_RPMDIR)" \
	-not -path "$(SRC_TESTDIR)" \
	-not -path "$(SRC_VAGRANTDIR)" )

## PacketFence variables
PF_DEV_RELEASE_PATH=https://raw.githubusercontent.com/inverse-inc/packetfence/devel/conf/pf-release
# X.Y
PF_DEV_MINOR_RELEASE=$(shell curl $(PF_DEV_RELEASE_PATH) | perl -ne 'print $$1 if (m/.*?(\d+\.\d+)./)')
