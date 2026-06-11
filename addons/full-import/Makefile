# This Makefile is only used to build packetfence-export package
ADDONS_DIR = /usr/local/pf/addons
FULL_IMPORT_DIR = /usr/local/pf/addons/full-import
FUNCTIONS_DIR = /usr/local/pf/addons/functions
SRC_ADDONS_DIR=$(shell dirname $(CURDIR))
SRC_FULLIMPORT_DIR=$(SRC_ADDONS_DIR)/full-import
SRC_FUNCTIONS_DIR=$(SRC_ADDONS_DIR)/functions
EXPORT_FILES_LIST = 'export.sh find-extra-files.pl'
ADDONS_FILES_LIST = 'exportable-backup.sh'

install:
	@echo "create directories"
	install -d -m0755 $(DESTDIR)$(ADDONS_DIR)
	install -d -m0755 $(DESTDIR)$(FULL_IMPORT_DIR)
	install -d -m0755 $(DESTDIR)$(FUNCTIONS_DIR)

	@echo "install full import files"
	for file in $(EXPORT_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(FULL_IMPORT_DIR) ; \
	done

	@echo "install addons files"
	for file in $(ADDONS_FILES_LIST); do \
	    install -v -m 0644 $(SRC_ADDONS_DIR)/$$file -D $(DESTDIR)$(ADDONS_DIR) ; \
	done

	@echo "install functions files"
	for file in `find $(SRC_FUNCTIONS_DIR) -type f -name "*.functions"` ; do \
		install -v -m 0644 $$file -D $(DESTDIR)$(FUNCTIONS_DIR) ; \
	done
