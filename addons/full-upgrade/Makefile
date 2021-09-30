FULL_UPGRADE_DIR = /usr/local/pf/addons/full-upgrade
SRC_ADDONS_DIR=$(shell dirname $(CURDIR))
SRC_FULLUPGRADE_DIR=$(SRC_ADDONS_DIR)/full-upgrade
SRC_FUNCTIONS_DIR=$(SRC_ADDONS_DIR)/functions

# full-upgrade dir is automatically created by install command
install:
	@echo "install subdirectories and files inside it"
	# /* to exclude directory himself
	for subdir in `find $(SRC_FULLUPGRADE_DIR)/* -type d -printf "%f\n"` ; do \
		install -d -m0755 $(DESTDIR)$(FULL_UPGRADE_DIR)/$$subdir ; \
		for file in `find $$subdir -type f`; do \
			install -v -m0644 $$file $(DESTDIR)$(FULL_UPGRADE_DIR)/$$subdir ; \
		done \
	done

	@echo "install top level $(SRC_FULLUPGRADE_DIR) files"
	for file in `find $(SRC_FULLUPGRADE_DIR) -maxdepth 1 -type f -not -name "Makefile"`; do \
            install -v -m 0644 $$file -D $(DESTDIR)$(FULL_UPGRADE_DIR) ; \
	done

	@echo "install functions files"
	for file in `find $(SRC_FUNCTIONS_DIR) -type f -name "*.functions"` ; do \
		install -v -m 0644 $$file -D $(DESTDIR)$(FULL_UPGRADE_DIR) ; \
	done
