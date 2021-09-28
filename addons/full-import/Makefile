# This Makefile is only used to build packetfence-upgrade package

FULL_IMPORT_DIR = /usr/local/pf/addons/full-import
UPGRADE_DIR = /usr/local/pf/addons/upgrade
EXPORT_FILES_LIST = 'export.sh find-extra-files.pl helpers.functions database.functions configuration.functions'
UPGRADE_FILES_LIST = 'do-upgrade.sh'

# targets are slightly different
# because Debian use full source and RPM use a minimal source

install_rpm:
	@echo "create directory $(DESTDIR)$(FULL_IMPORT_DIR)"
	install -d -m0755 $(DESTDIR)$(FULL_IMPORT_DIR)

	@echo "install full import files"
	for file in $(EXPORT_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(FULL_IMPORT_DIR) ; \
	done

	@echo "create directory $(DESTDIR)$(UPGRADE_DIR)"
	install -d -m0755 $(DESTDIR)$(UPGRADE_DIR)

	@echo "install upgrade files"
	for file in $(UPGRADE_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(UPGRADE_DIR) ; \
	done

install_deb:
	@echo "create directory $(DESTDIR)$(FULL_IMPORT_DIR)"
	install -d -m0755 $(DESTDIR)$(FULL_IMPORT_DIR)

	@echo "install full import files"
	for file in $(EXPORT_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(FULL_IMPORT_DIR) ; \
	done

	@echo "create directory $(DESTDIR)$(UPGRADE_DIR)"
	install -d -m0755 $(DESTDIR)$(UPGRADE_DIR)

	@echo "install upgrade files"
	for file in $(UPGRADE_FILES_LIST); do \
	    install -v -m 0644 ../upgrade/$$file -D $(DESTDIR)$(UPGRADE_DIR) ; \
	done
