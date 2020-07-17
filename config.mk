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
GOBINARIES = pfhttpd pfdhcp pfdns pfstats pfdetect galera-autofix pfacct pfcertmanager

# SRC HTML dirs
SRC_HTMLDIR = html
SRC_HTML_CPDIR = $(SRC_HTMLDIR)/captive-portal
SRC_HTML_COMMONDIR = $(SRC_HTMLDIR)/common
SRC_HTML_PARKINGDIR = $(SRC_HTMLDIR)/parking
SRC_HTML_PFAPPDIR = $(SRC_HTMLDIR)/pfappserver
SRC_HTML_PFAPPDIR_ROOT = $(SRC_HTMLDIR)/pfappserver/root
SRC_HTML_PFAPPDIR_STATIC = $(SRC_HTML_PFAPPDIR_ROOT)/static
SRC_HTML_PFAPPDIR_ALT = $(SRC_HTML_PFAPPDIR_ROOT)/static.alt
SRC_HTML_PFAPPDIR_LIB = $(SRC_HTML_PFAPPDIR)/lib/pfappserver
SRC_HTML_PFAPPDIR_I18N = $(SRC_HTML_PFAPPDIR_LIB)/I18N

# Installed HTLML dirs
HTMLDIR = $(PF_PREFIX)/html
HTML_CPDIR = $(HTMLDIR)/captive-portal
HTML_COMMONDIR = $(HTMLDIR)/common
HTML_PARKINGDIR = $(HTMLDIR)/parking
HTML_PFAPPDIR = $(HTMLDIR)/pfappserver
HTML_PFAPPDIR_ROOT = $(HTMLDIR)/pfappserver/root
HTML_PFAPPDIR_STATIC = $(HTML_PFAPPDIR_ROOT)/static
HTML_PFAPPDIR_ALT = $(HTML_PFAPPDIR_ROOT)/static.alt
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

# pfappserver files without static and static.alt
pfapp_files = $(shell find $(SRC_HTML_PFAPPDIR) \
	-type f \
	-not -name "Changes" \
	-not -path "$(SRC_HTML_PFAPPDIR)/root-custom*" \
	-not -path "$(SRC_HTML_PFAPPDIR)/t/*" \
	-not -path "$(SRC_HTML_PFAPPDIR_STATIC)*" \
	-not -path "$(SRC_HTML_PFAPPDIR_ALT)*")

pfapp_static_files = $(shell find $(SRC_HTML_PFAPPDIR_STATIC) \
	-type f \
	-not -path "$(SRC_HTML_PFAPPDIR_STATIC)/bower_components/*" \
	-not -path "$(SRC_HTML_PFAPPDIR_STATIC)/node_modules/*")

pfapp_alt_files = $(shell find $(SRC_HTML_PFAPPDIR_ALT) \
	-type f \
	-not -path "$(SRC_HTML_PFAPPDIR_ALT)/node_modules/*")

symlink_files = $(shell find $(SRC_HTML_PFAPPDIR) \
	-type l \
	-not -path "$(SRC_HTML_PFAPPDIR_STATIC)/node_modules/*" \
	-not -path "$(SRC_HTML_PFAPPDIR_ALT)/node_modules/*")
