# This Makefile is only used to build packetfence-upgrade package

FULL_IMPORT_DIR = /usr/local/pf/addons/full-import
UPGRADE_DIR = /usr/local/pf/addons/upgrade
EXPORT_FILES_LIST = 'export.sh find-extra-files.pl helpers.functions database.functions'
UPGRADE_FILES_LIST = 'do-upgrade.sh'

install:
	@echo "create directory $(DESTDIR)$(FULL_IMPORT_DIR)"
	install -d -m0755 $(DESTDIR)$(FULL_IMPORT_DIR)

	@echo "install full import files"
	for file in $(EXPORT_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(FULL_IMPORT_DIR) ; \
	done

	# we don't create upgrade dir, previous packetfence installs
	# already did it
	@echo "install upgrade files"
	for file in $(UPGRADE_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(UPGRADE_DIR) ; \
	done
