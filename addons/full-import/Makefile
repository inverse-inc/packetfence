# This Makefile is only used to build packetfence-export package

FULL_IMPORT_DIR = /usr/local/pf/addons/full-import
EXPORT_FILES_LIST = 'export.sh find-extra-files.pl helpers.functions database.functions'

install:
	@echo "create directory $(DESTDIR)$(FULL_IMPORT_DIR)"
	install -d -m0755 $(DESTDIR)$(FULL_IMPORT_DIR)

	@echo "install full import files"
	for file in $(EXPORT_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(FULL_IMPORT_DIR) ; \
	done
