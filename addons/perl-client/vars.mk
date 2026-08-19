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

## Packaging
# Mirrors config.mk:88-106 so fingerbank packages keep the version suffix that
# ci-build-pkg produced (PKG_BUILD_SUFFIX_MODE=long). GitHub Actions exports
# CI_COMMIT_REF_NAME and CI_PIPELINE_ID; fall back to git for manual builds.
CI_COMMIT_REF_NAME  ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo local)
CI_PIPELINE_ID      ?= 0
CI_COMMIT_TIMESTAMP ?= $(shell git show -s --format=%cI HEAD 2>/dev/null)
CI_COMMIT_DATE      := $(shell date -u -d "$(CI_COMMIT_TIMESTAMP)" +%Y%m%d%H%M%S 2>/dev/null || date -u +%Y%m%d%H%M%S)
CI_COMMIT_REF_SLUG  ?= $(shell printf '%s' "$(CI_COMMIT_REF_NAME)" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-\+/-/g; s/^-//; s/-$$//')
CI_COMMIT_REF_TILDE := $(shell printf '%s' "$(CI_COMMIT_REF_SLUG)" | tr '_/-' '~')

OS_RELEASE_ID   := $(shell . /etc/os-release 2>/dev/null && printf '%s' "$$ID" || echo unknown)
OS_RELEASE_NAME := $(shell . /etc/os-release 2>/dev/null && printf '%s' "$${VERSION_CODENAME:-$${VERSION_ID%%.*}}" || echo unknown)
OS_RELEASE_NUM  := $(shell . /etc/os-release 2>/dev/null && printf '%04d' "$${VERSION_ID%%.*}" 2>/dev/null || printf '0000')

DEB_PKG_SUFFIX  := +$(CI_COMMIT_DATE)+$(CI_PIPELINE_ID)+$(OS_RELEASE_NUM)+$(CI_COMMIT_REF_TILDE)+$(OS_RELEASE_NAME)
RPM_PKG_SUFFIX  := $(CI_COMMIT_DATE).$(CI_PIPELINE_ID).$(OS_RELEASE_NUM).$(CI_COMMIT_REF_TILDE)

# centos:8 -> result/centos/8, debian:bookworm -> result/debian/bookworm
PKG_RESULT_DIR  ?= $(SRC_RESULTDIR)
PKG_RELEASE_DIR  = $(PKG_RESULT_DIR)/$(OS_RELEASE_ID)/$(OS_RELEASE_NAME)
