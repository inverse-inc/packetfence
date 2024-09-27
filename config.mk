#==============================================================================
# PacketFence application
#==============================================================================
#
# Base directories
#
PREFIX = /usr/local
PF_PREFIX = $(PREFIX)/pf
PFCONNECTOR_PREFIX = $(PREFIX)/pfconnector-remote

# PF
BINDIR = $(PF_PREFIX)/bin
SBINDIR = $(PF_PREFIX)/sbin
TESTDIR = $(PF_PREFIX)/t
CIDIR = $(PF_PREFIX)/ci
CILIBDIR = $(CIDIR)/lib

# PF connector
PFCONNECTOR_BINDIR = $(PFCONNECTOR_PREFIX)/bin
PFCONNECTOR_CONFDIR = $(PFCONNECTOR_PREFIX)/conf
PFCONNECTOR_LOGDIR = $(PFCONNECTOR_PREFIX)/logs
PFCONNECTOR_UPGRADEDIR = $(PFCONNECTOR_PREFIX)/upgrade

# source dirs
# hack to get directory of config.mk from any Makefile in source tree
# even if make is called with -C
SRC_ROOT_DIR = $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SRC_RPMDIR = $(SRC_ROOT_DIR)/rpm
SRC_DEBDIR = $(SRC_ROOT_DIR)/debian
SRC_CONFDIR = $(SRC_ROOT_DIR)/conf
SRC_SYSTEMD_DIR = $(SRC_CONFDIR)/systemd
SRC_CIDIR = $(SRC_ROOT_DIR)/ci
SRC_CI_TESTDIR = $(SRC_CIDIR)/lib/test
SRC_GODIR = $(SRC_ROOT_DIR)/go
SRC_TESTDIR= $(SRC_ROOT_DIR)/t
SRC_RELATIVE_TESTDIR = t
SRC_RELATIVE_CILIBDIR = ci/lib
SRC_ADDONSDIR = $(SRC_ROOT_DIR)/addons
SRC_FULL_IMPORTDIR = $(SRC_ADDONSDIR)/full-import
SRC_FULL_UPGRADEDIR = $(SRC_ADDONSDIR)/full-upgrade
SRC_FUNCTIONSDIR = $(SRC_ADDONSDIR)/functions
SRC_PFCONNECTORDIR = $(SRC_ADDONSDIR)/pfconnector
SRC_DOCKERDIR = $(SRC_ROOTDIR)/docker

# specific directory to build website artifacts
SRC_WEBSITE_DIR = $(SRC_ROOT_DIR)/website

# Containers
KNK_REGISTRY = ghcr.io
KNK_REGISTRY_URL = ghcr.io/inverse-inc/packetfence
LOCAL_REGISTRY = packetfence
#
# Golang
#
GOVERSION = go1.23.1
PF_BINARIES = pfhttpd pfqueue-go pfdhcp pfdns pfstats pfdetect galera-autofix pfacct pfcron mysql-probe pfconnector sdnotify-proxy
PF_GO_CMDS = pfcrypt

#
# PF versions
#
PF_RELEASE_PATH=$(shell readlink -e $(SRC_ROOT_DIR)/conf/pf-release)

# X.Y
PF_MINOR_RELEASE=$(shell perl -ne 'print $$1 if (m/.*?(\d+\.\d+)./)' $(PF_RELEASE_PATH))
# X.Y.Z
PF_PATCH_RELEASE=$(shell perl -ne 'print $$1 if (m/.*?(\d+\.\d+\.\d+)/)' $(PF_RELEASE_PATH))

# SRC HTML dirs
SRC_HTMLDIR = $(SRC_ROOT_DIR)/html
SRC_HTML_CPDIR = $(SRC_HTMLDIR)/captive-portal
SRC_HTML_COMMONDIR = $(SRC_HTMLDIR)/common
SRC_HTML_PARKINGDIR = $(SRC_HTMLDIR)/parking
SRC_HTML_PFAPPDIR = $(SRC_HTMLDIR)/pfappserver
SRC_HTML_PFAPPDIR_ROOT = $(SRC_HTMLDIR)/pfappserver/root
SRC_HTML_PFAPPDIR_LIB = $(SRC_HTML_PFAPPDIR)/lib/pfappserver
SRC_HTML_PFAPPDIR_I18N = $(SRC_HTML_PFAPPDIR_LIB)/I18N

# Installed HTLML dirs
HTMLDIR = $(PF_PREFIX)/html
HTML_CPDIR = $(HTMLDIR)/captive-portal
HTML_COMMONDIR = $(HTMLDIR)/common
HTML_PARKINGDIR = $(HTMLDIR)/parking
HTML_PFAPPDIR = $(HTMLDIR)/pfappserver
HTML_PFAPPDIR_ROOT = $(HTMLDIR)/pfappserver/root
HTML_PFAPPDIR_LIB = $(HTML_PFAPPDIR)/lib/pfappserver
HTML_PFAPPDIR_I18N = $(HTML_PFAPPDIR_LIB)/I18N

# parking files
parking_files = $(shell find $(SRC_HTML_PARKINGDIR) \
	-type f)

# common files
# exclude node_modules dir and subdirs
common_files = $(shell find $(SRC_HTML_COMMONDIR) \
	-type f \
	-not -path "$(SRC_HTML_COMMONDIR)/node_modules/*")

# captive portal files
cp_files = $(shell find $(SRC_HTML_CPDIR) \
	-type f \
	-not -path "$(SRC_HTML_CPDIR)/content/node_modules/*" \
	-not -path "$(SRC_HTML_CPDIR)/profile-templates/*" \
	-not -path "$(SRC_HTML_CPDIR)/t/*")

# pfappserver files without root
pfapp_files = $(shell find $(SRC_HTML_PFAPPDIR) \
	-type f \
	-not -name "Changes" \
	-not -path "$(SRC_HTML_PFAPPDIR)/root-custom*" \
	-not -path "$(SRC_HTML_PFAPPDIR)/t/*" \
	-not -path "$(SRC_HTML_PFAPPDIR_ROOT)*")

pfapp_alt_files = $(shell find $(SRC_HTML_PFAPPDIR_ROOT) \
	-type f \
	-not -path "$(SRC_HTML_PFAPPDIR_ROOT)/node_modules/*")

symlink_files = $(shell find $(SRC_HTML_PFAPPDIR) \
	-type l \
	-not -path "$(SRC_HTML_PFAPPDIR_ROOT)/node_modules/*")

# all directories and files to include in packetfence package
# $(SRC_ROOT_DIR)/* to exclude SRC_ROOT_DIR himself
# if you exclude a subdirectory be sure to not include a top level directory
files_to_include = $(shell find $(SRC_ROOT_DIR)/* \
	-maxdepth 0 \
	-not -path "$(SRC_CIDIR)" \
	-not -path "$(SRC_DEBDIR)" \
	-not -path "$(SRC_ROOT_DIR)/packetfence-$(PF_PATCH_RELEASE)" \
	-not -path "$(SRC_ROOT_DIR)/public" \
	-not -path "$(SRC_RPMDIR)" \
	-not -path "$(SRC_TESTDIR)" )

# all directories and files to include in packetfence-test package
pf_test_files_to_include = $(shell find $(SRC_TESTDIR) \
	-maxdepth 0)

# all directories and files to include in packetfence-export package
# reflect source tree layout
pf_export_files_to_include = $(shell find $(SRC_FULL_IMPORTDIR)/ \
	$(SRC_FUNCTIONSDIR)/ \
	-maxdepth 0)

# all directories and files to include in packetfence-upgrade package
 # reflect source tree layout
pf_upgrade_files_to_include = $(shell find $(SRC_FULL_UPGRADEDIR)/ \
	$(SRC_FUNCTIONSDIR)/ \
	-maxdepth 0)
