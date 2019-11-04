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

# HTML dirs
HTMLDIR = $(PFPREFIX)/html
HTML_CPDIR = $(HTMLDIR)/captive-portal
HTML_COMMONDIR = $(HTMLDIR)/common
HTML_PARKINGDIR = $(HTMLDIR)/parking
HTML_PFAPPDIR = $(HTMLDIR)/pfappserver


# HTML files
parking_files = $(notdir $(wildcard ./html/parking/*))

# '*' after dir name don't match current directory
# exclude node_modules dir and subdirs
common_dirs = $(shell find html/common/* ! -path "html/common/node_modules*" -type d)

# exclude package.json and package-lock.json
common_files = $(shell find html/common/* -type f -not -name "package*.json") 
