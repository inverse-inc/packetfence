FULL_UPGRADE_DIR = /usr/local/pf/addons/full-upgrade
FULL_UPGRADE_FILES_LIST = 'run-upgrade.sh'

# full-upgrade dir is automatically created by install command
install:
	@echo "install base directory and subdirectories"
	# /* to exclude directory himself
	for subdir in `find $(CURDIR)/* -type d -printf "%f\n"` ; do \
		install -d -m0755 $(DESTDIR)/usr/local/pf/addons/full-upgrade/$$subdir ; \
		for file in `find $$subdir -type f`; do \
			install -m0644 $$file $(DESTDIR)/usr/local/pf/addons/full-upgrade/$$subdir ; \
		done \
	done

	@echo "install full upgrade files"
	for file in $(FULL_UPGRADE_FILES_LIST); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(FULL_UPGRADE_DIR) ; \
	done
