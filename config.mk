GOVERSION = go1.13.1
GOBINARIES = pfhttpd pfdhcp pfdns pfstats pfdetect
DOCKER_TAG = latest
REGISTRY = docker.io

### CI
ANSIBLE_CENTOS_GROUP = devel_centos
ANSIBLE_DEBIAN_GROUP = devel_debian
ANSIBLE_RUBYGEMS_GROUP = devel_rubygems

### PacketFence
PREFIX = /usr/local
PFPREFIX = $(PREFIX)/pf
BINDIR = $(PFPREFIX)/bin
SBINDIR = $(PFPREFIX)/sbin

# SRC HTML dirs
SRC_HTMLDIR = html
SRC_HTML_CPDIR = $(SRC_HTMLDIR)/captive-portal
SRC_HTML_COMMONDIR = $(SRC_HTMLDIR)/common
SRC_HTML_PARKINGDIR = $(SRC_HTMLDIR)/parking
SRC_HTML_PFAPPDIR = $(SRC_HTMLDIR)/pfappserver

# Installed HTLML dirs
HTMLDIR = $(PFPREFIX)/html
HTML_CPDIR = $(HTMLDIR)/captive-portal
HTML_COMMONDIR = $(HTMLDIR)/common
HTML_PARKINGDIR = $(HTMLDIR)/parking
HTML_PFAPPDIR = $(HTMLDIR)/pfappserver

# parking files
parking_files = $(notdir $(wildcard ./$(SRC_HTML_PARKINGDIR)/*))

# common files and dirs
# '*' after dir name don't match current directory
# exclude node_modules dir and subdirs
common_dirs = $(shell find $(SRC_HTML_COMMONDIR)/* ! -path "$(SRC_HTML_COMMONDIR)/node_modules*" -type d)

# exclude package.json and package-lock.json
common_files = $(shell find $(SRC_HTML_COMMONDIR)/* -type f -not -name "package*.json") 

# captive portal files and dirs
cp_dirs = $(shell find $(SRC_HTML_CPDIR)/* -type d)
cp_files = $(shell find $(SRC_HTML_CPDIR)/* -type f)
