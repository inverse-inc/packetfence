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
SRC_HTML_PFAPPDIR_STATIC = $(SRC_HTML_PFAPPDIR)/root/static
SRC_HTML_PFAPPDIR_ALT = $(SRC_HTML_PFAPPDIR)/root/static.alt

# Installed HTLML dirs
HTMLDIR = $(PF_PREFIX)/html
HTML_CPDIR = $(HTMLDIR)/captive-portal
HTML_COMMONDIR = $(HTMLDIR)/common
HTML_PARKINGDIR = $(HTMLDIR)/parking
HTML_PFAPPDIR = $(HTMLDIR)/pfappserver
HTML_PFAPPDIR_STATIC = $(HTML_PFAPPDIR)/root/static
HTML_PFAPPDIR_ALT = $(HTML_PFAPPDIR)/root/static.alt

# parking files
parking_files = $(notdir $(wildcard ./$(SRC_HTML_PARKINGDIR)/*))

# common files and dirs
# '*' after dir name don't match current directory
# exclude node_modules dir and subdirs
common_dirs = $(shell find $(SRC_HTML_COMMONDIR)/* ! -path "$(SRC_HTML_COMMONDIR)/node_modules*" -type d)

# exclude package.json and package-lock.json
common_files = $(shell find $(SRC_HTML_COMMONDIR)/* -type f -not -name "package*.json") 

# captive portal files and dirs
cp_dirs = $(shell find $(SRC_HTML_CPDIR)/* ! -path "$(SRC_HTML_CPDIR)/content/node_modules*" -type d)
cp_files = $(shell find $(SRC_HTML_CPDIR)/* -type f)

# pfappserver files and dirs without root and useless dirs
pfapp_dirs = $(shell find $(SRC_HTML_PFAPPDIR)/* -type d ! -path "html/pfappserver/root-custom*" -and ! -path "html/pfappserver/t*" -and ! -path "html/pfappserver/root*")
pfapp_files = $(shell find $(SRC_HTML_PFAPPDIR)/* -type f -not -name "Changes" ! -path "html/pfappserver/root-custom*" -and ! -path "html/pfappserver/t*" -and ! -path "html/pfappserver/root*")

pfapp_other_dirs = $(shell find $(SRC_HTML_PFAPPDIR)/* -maxdepth 0 -type d ! -path "html/pfappserver/root-custom*" -and ! -path "html/pfappserver/t*")
pfapp_other_files = $(shell find $(SRC_HTML_PFAPPDIR)/* -maxdepth 0 -type f -not -name "Changes")

# node_modules (static), (static.alt)
# node_modules (static), (static.alt)
