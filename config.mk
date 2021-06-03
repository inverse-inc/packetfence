#==============================================================================
# PacketFence application
#==============================================================================
#
# Base directories
#
PREFIX = /usr/local
PF_PREFIX = $(PREFIX)/pf
BINDIR = $(PF_PREFIX)/bin
SBINDIR = $(PF_PREFIX)/sbin
# source dirs
# hack to get directory of config.mk from any Makefile in source tree
# even if make is called with -C
SRC_ROOT_DIR = $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SRC_RPMDIR = $(SRC_ROOT_DIR)/rpm
SRC_DEBDIR = $(SRC_ROOT_DIR)/debian
SRC_CIDIR = $(SRC_ROOT_DIR)/ci

#
# Golang
#
GOVERSION = go1.16.4
PF_BINARIES = pfhttpd pfdhcp pfdns pfstats pfdetect galera-autofix pfacct pfcertmanager pfcron

#
# PF version
#
PF_RELEASE_PATH=$(shell readlink -e $(SRC_ROOT_DIR)/conf/pf-release)
PF_MINOR_RELEASE=$(shell perl -ne 'print $$1 if (m/.*?(\d+\.\d+)./)' $(PF_RELEASE_PATH))

# SRC HTML dirs
SRC_HTMLDIR = html
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
