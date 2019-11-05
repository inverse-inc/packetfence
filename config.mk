#==============================================================================
# CI
#==============================================================================

#
# Packer
#
DOCKER_TAG = latest
REGISTRY = docker.io
ANSIBLE_CENTOS_GROUP = devel_centos
ANSIBLE_DEBIAN_GROUP = devel_debian
ANSIBLE_RUBYGEMS_GROUP = devel_rubygems


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

#
# Golang
#
GOVERSION = go1.13.1
GOBINARIES = pfhttpd pfdhcp pfdns pfstats pfdetect

# SRC HTML dirs
SRC_HTMLDIR = html
SRC_HTML_CPDIR = $(SRC_HTMLDIR)/captive-portal
SRC_HTML_COMMONDIR = $(SRC_HTMLDIR)/common
SRC_HTML_PARKINGDIR = $(SRC_HTMLDIR)/parking
SRC_HTML_PFAPPDIR = $(SRC_HTMLDIR)/pfappserver
SRC_HTML_PFAPPDIR_ROOT = $(SRC_HTMLDIR)/pfappserver/root
SRC_HTML_PFAPPDIR_STATIC = $(SRC_HTML_PFAPPDIR_ROOT)/static
SRC_HTML_PFAPPDIR_ALT = $(SRC_HTML_PFAPPDIR_ROOT)/static.alt

# Installed HTLML dirs
HTMLDIR = $(PF_PREFIX)/html
HTML_CPDIR = $(HTMLDIR)/captive-portal
HTML_COMMONDIR = $(HTMLDIR)/common
HTML_PARKINGDIR = $(HTMLDIR)/parking
HTML_PFAPPDIR = $(HTMLDIR)/pfappserver
HTML_PFAPPDIR_ROOT = $(HTMLDIR)/pfappserver/root
HTML_PFAPPDIR_STATIC = $(HTML_PFAPPDIR_ROOT)/static
HTML_PFAPPDIR_ALT = $(HTML_PFAPPDIR_ROOT)/static.alt

# parking files
parking_files = $(notdir $(wildcard ./$(SRC_HTML_PARKINGDIR)/*))

# common files and dirs
# '*' after dir name don't match current directory
# exclude node_modules dir and subdirs
common_dirs = $(shell find $(SRC_HTML_COMMONDIR)/* \
	-type d \
	-not -path "$(SRC_HTML_COMMONDIR)/node_modules*")

# exclude package.json and package-lock.json
common_files = $(shell find $(SRC_HTML_COMMONDIR)/* \
	-type f \
	-not -name "package*.json")

# captive portal files and dirs
cp_dirs = $(shell find $(SRC_HTML_CPDIR)/* \
	-type d \
	-not -path "$(SRC_HTML_CPDIR)/content/node_modules*" \
	-and -not -path "$(SRC_HTML_CPDIR)/t*")

cp_files = $(shell find $(SRC_HTML_CPDIR)/* \
	-type f \
	-not -path "$(SRC_HTML_CPDIR)/content/node_modules*" \
	-and -not -path "$(SRC_HTML_CPDIR)/t*")

# pfappserver files and dirs without root and useless dirs
pfapp_dirs = $(shell find $(SRC_HTML_PFAPPDIR)/* \
	-type d \
	-not -path "$(SRC_HTML_PFAPPDIR)/root-custom*" \
	-and -not -path "$(SRC_HTML_PFAPPDIR)/t*" \
	-and -not -path "$(SRC_HTML_PFAPPDIR)/root*")

pfapp_files = $(shell find $(SRC_HTML_PFAPPDIR)/* \
	-type f \
	-not -name "Changes" \
	-not -path "$(SRC_HTML_PFAPPDIR)/root-custom*" \
	-and -not -path "$(SRC_HTML_PFAPPDIR)/t*" \
	-and -not -path "$(SRC_HTML_PFAPPDIR)/root*")

pfapp_static_dir = $(shell find $(SRC_HTML_PFAPPDIR_STATIC)/* \
	-type d \
	-not -path "$(SRC_HTML_PFAPPDIR_STATIC)/bower_components*" \
	-and -not -path "$(SRC_HTML_PFAPPDIR_STATIC)/node_modules*")

pfapp_static_files = $(shell find $(SRC_HTML_PFAPPDIR_STATIC)/* \
	-type f \
	-not -name "package*.json" \
	-and -not -name "bower.json" \
	-and -not -path "$(SRC_HTML_PFAPPDIR_STATIC)/bower_components*" \
	-and -not -path "$(SRC_HTML_PFAPPDIR_STATIC)/node_modules*")

# pfapp_alt_dir = $(shell find $(SRC_HTML_PFAPPDIR_ALT)/* -type d ! -path "html/pfappserver/root-custom*" -and ! -path "html/pfappserver/t*")
# pfapp_alt_files = $(shell find $(SRC_HTML_PFAPPDIR_ALT)/* -type f -not -name "")

# node_modules (static), (static.alt)
# node_modules (static), (static.alt)
