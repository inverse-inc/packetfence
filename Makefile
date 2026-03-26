include config.mk

PF_UDF_OBJ = $(patsubst src/mariadb_udf/%.c, src/mariadb_udf/%.o, $(filter-out src/mariadb_udf/pf_udf.c src/mariadb_udf/test_pf_udf.c, $(wildcard src/mariadb_udf/*.c)))
MYSQL_SUFFIX=

all:
	@echo "Please chose which documentation to build:"
	@echo ""
	@echo " 'pdf' will build all guides using the PDF format"
	@echo " 'docs/PacketFence_Installation_Guide.pdf' will build the Installation guide in PDF"
	@echo " 'docs/PacketFence_Clustering_Guide.pdf' will build the Clustering guide in PDF"
	@echo " 'docs/PacketFence_Developers_Guide.pdf' will build the Developers guide in PDF"
	@echo " 'docs/PacketFence_Network_Devices_Configuration_Guide.pdf' will build the Network Devices Configuration guide in PDF"
	@echo " 'docs/PacketFence_Upgrade_Guide.pdf' will build the Upgrade guide in PDF"

ASCIIDOCS := $(notdir $(wildcard docs/PacketFence_*.asciidoc))
PDFS = $(patsubst %.asciidoc,docs/%.pdf, $(ASCIIDOCS))

clean:
	rm -f docs/*.html docs/index.js docs/*.pdf docs/styles/*.min.css

docs/%.pdf: docs/%.asciidoc
	asciidoctor-pdf \
		-a pdf-theme=docs/asciidoctor-pdf-theme.yml \
		-a pdf-fontsdir=docs/fonts \
		-a release_version=$(PF_PATCH_RELEASE) \
		-a release_minor=$(PF_MINOR_RELEASE) \
		-a release_month=`date +%B` \
		$<

.PHONY: pdf

pdf: $(PDFS)

HTML = $(patsubst %.asciidoc,docs/%.html, $(ASCIIDOCS))
MINCSS = docs/styles/app.min.css

docs/styles/%.min.css: docs/styles/%.css
	@echo "Minify CSS styles for html docs: $<"
	npx --yes --package clean-css-cli cleancss --inline remote $< -o $@

.PHONY: css
css: $(MINCSS)

docs/%.html: docs/%.asciidoc $(MINCSS)
	asciidoctor \
		-n \
		-r ./docs/asciidoctor-html.rb \
		-a stylesheet=styles/app.min.css \
		-a release_version=$(PF_PATCH_RELEASE) \
		-a release_minor=$(PF_MINOR_RELEASE) \
		-a release_month=`date +%B` \
		$<

docs/index.js: $(HTML)
	html_json=$$(find $$(dirname "$@") -type f -iname '*.html' -not -iname '*template*' -printf '{"name":"%f","size":%s,"last_modifed":%T@}\n' | jq -s '[.[] | {name, size, last_modifed: (.last_modifed*1000 | floor)}]'); \
	pdf_json=$$(find $$(dirname "$@") -type f -iname '*.pdf' -printf '{"name":"%f","size":%s}\n' | jq -s '.'); \
	jq -n --argjson html "$$html_json" --argjson pdfs "$$pdf_json" \
		'{ items: [$$html[] | . as $$h | ($$h.name | sub("\\.html$$"; ".pdf")) as $$pn | ($$pdfs | map(select(.name == $$pn)) | .[0]) as $$pdf | if $$pdf then . + {pdf_size: $$pdf.size} else . end] }' > $@

.PHONY: images

images:
	@echo "install images dir and all subdirectories"
	for subdir in `find docs/images/* -type d -printf "%f\n"` ; do \
		install -d -m0755 $(DESTDIR)/usr/local/pf/docs/images/$$subdir ; \
		for img in `find docs/images/$$subdir -type f`; do \
			install -m0644 $$img $(DESTDIR)/usr/local/pf/docs/images/$$subdir ; \
		done \
	done
	@echo "install only images at depth0 in images/ directory"
	for img in `find docs/images/* -maxdepth 0 -type f`; do \
		install -m0644 $$img $(DESTDIR)/usr/local/pf/docs/images/ ; \
	done

.PHONY: html

html: $(HTML) docs/index.js

pfcmd.help:
	/usr/local/pf/bin/pfcmd help > docs/installation/pfcmd.help

.PHONY: configurations

configurations: SHELL:=/bin/bash
configurations:
	find -type f -name '*.example' -print0 | while read -d $$'\0' file; do cp -n $$file "$$(dirname $$file)/$$(basename $$file .example)"; done
	touch conf/pf.conf
	touch conf/pfconfig.conf

.PHONY: configurations_force

configurations_hard: SHELL:=/bin/bash
configurations_hard:
	find -type f -name '*.example' -print0 | while read -d $$'\0' file; do cp $$file "$$(dirname $$file)/$$(basename $$file .example)"; done
	touch conf/pf.conf
	touch conf/pfconfig.conf

# server certs and keys
# the | in the prerequisites ensure the target is not created if it already exists
# see https://www.gnu.org/software/make/manual/make.html#Prerequisite-Types
conf/ssl/server.pem: | conf/ssl/server.key conf/ssl/server.crt conf/ssl/server.pem
	cat conf/ssl/server.crt conf/ssl/server.key > conf/ssl/server.pem

conf/ssl/server.crt: | conf/ssl/server.crt
	openssl req -new -x509 -days 365 \
	-out conf/ssl/server.crt \
	-key conf/ssl/server.key \
	-config conf/openssl.cnf

conf/ssl/server.key: | conf/ssl/server.key
	openssl genrsa -out conf/ssl/server.key 2048

conf/local_secret:
	date +%s | sha256sum | base64 | head -c 32 > conf/local_secret

conf/unified_api_system_pass:
	date +%s | sha256sum | base64 | head -c 32 > conf/unified_api_system_pass

conf/system_init_key:
	hexdump -e '/1 "%x"' < /dev/urandom | head -c 32 > conf/system_init_key

bin/pfcmd: src/pfcmd.c
	$(CC) -O2 -g -std=c99  -Wall $< -o $@

bin/ntlm_auth_wrapper: src/ntlm_auth_wrap.c
	$(CC) -g -std=c99 -Wall $< -o $@ -lcurl -lcjson

src/mariadb_udf/pf_udf.so: src/mariadb_udf/pf_udf.c $(PF_UDF_OBJ)
	$(CC) -O2 -Wall -g $$(pkg-config libmariadb --cflags|sed -e 's/[[:space:]]*$$//')$(MYSQL_SUFFIX) -fPIC -shared -o $@ $< $(PF_UDF_OBJ)

src/mariadb_udf/%.o: src/mariadb_udf/%.c src/mariadb_udf/%.h
	$(CC) $(TEST_CFLAGS) $(CFLAGS) -fPIC -c $< -o $@

src/mariadb_udf/test_pf_udf: src/mariadb_udf/test_pf_udf.c $(PF_UDF_OBJ)
	$(CC) -O2 -g -Wall $< $(PF_UDF_OBJ) -o $@

.PHONY: test_pf_udf
test_pf_udf: src/mariadb_udf/test_pf_udf
	./src/mariadb_udf/test_pf_udf

.PHONY: permissions

/etc/sudoers.d/packetfence.sudoers: packetfence.sudoers
	cp packetfence.sudoers /etc/sudoers.d/packetfence

.PHONY: sudo

sudo: /etc/sudoers.d/packetfence.sudoers


permissions: bin/pfcmd
	./bin/pfcmd fixpermissions

raddb/certs/server.crt:
	cd raddb/certs; make

.PHONY: raddb-sites-enabled

raddb/sites-enabled:
	mkdir raddb/sites-enabled
	cd raddb/sites-enabled;\
	for f in packetfence packetfence-tunnel dynamic-clients status;\
		do ln -s ../sites-available/$$f $$f;\
	done

.PHONY: translation

translation:
	for TRANSLATION in de en es fr he_IL it nb_NO nl pl_PL pt_BR tr_TR; do\
		/usr/bin/msgfmt conf/locale/$$TRANSLATION/LC_MESSAGES/packetfence.po\
		  --output-file conf/locale/$$TRANSLATION/LC_MESSAGES/packetfence.mo;\
	done

.PHONY: mysql-schema

mysql-schema:
	ln -f -s /usr/local/pf/db/pf-schema-X.Y.sql /usr/local/pf/db/pf-schema.sql;

.PHONY: chown_pf

chown_pf:
	chown -R pf:pf *

.PHONY: fingerbank

fingerbank:
	rm -f /usr/local/pf/lib/fingerbank
	ln -s /usr/local/fingerbank/lib/fingerbank /usr/local/pf/lib/fingerbank \

.PHONY: systemd

systemd:
	cp /usr/local/pf/conf/systemd/packetfence* /usr/lib/systemd/system/
	systemctl daemon-reload

.PHONY: pf-dal

pf-dal:
	perl /usr/local/pf/addons/dev-helpers/bin/generator-data-access-layer.pl

devel: configurations conf/ssl/server.key conf/ssl/server.crt conf/local_secret bin/pfcmd raddb/certs/server.crt \
	sudo translation mysql-schema raddb/sites-enabled fingerbank chown_pf permissions bin/ntlm_auth_wrapper conf/unified_api_system_pass conf/system_init_key

test:
	cd t && ./smoke.t

.PHONY: html_httpd.admin_dispatcher
# Target to install only necessary files in httpd.admin_dispatcher image
html_httpd.admin_dispatcher:
	@echo "create directories under $(DESTDIR)$(HTMLDIR)"
	install -d -m0755 $(DESTDIR)$(HTML_COMMONDIR)
	install -d -m0755 $(DESTDIR)$(HTML_PFAPPDIR)

	@echo "install $(SRC_HTML_COMMONDIR) dirs and files"
	for file in $(common_files); do \
	    install -v -m 0644 $$file -D $(DESTDIR)$(PF_PREFIX)/$$file ; \
	done

	@echo "install $(SRC_HTML_PFAPPDIR) without root dir"
	for file in $(pfapp_files); do \
	    install -v -m 0644 $$file -D $(DESTDIR)$(PF_PREFIX)/$$file ; \
	done

	@echo "install $(SRC_HTML_PFAPPDIR_ROOT) dirs and files"
	for file in $(pfapp_alt_files); do \
	    install -v -m 0644 $$file -D $(DESTDIR)$(PF_PREFIX)/$$file ; \
	done

	@echo "install symlinks"
	for link in $(symlink_files); do \
	    cp -v --no-dereference $$link $(DESTDIR)$(PF_PREFIX)/$$link ; \
	done

.PHONY: conf/git_commit_id
conf/git_commit_id:
	git rev-parse HEAD > $@

.PHONY: conf/build_id
conf/build_id:
	$(SRC_CIDIR)/lib/build/generate-build-id.sh

.PHONY: rpm/.rpmmacros
rpm/.rpmmacros:
	echo "%systemddir /usr/lib/systemd" > $(SRC_RPMDIR)/.rpmmacros
	echo "%pf_minor_release $(PF_MINOR_RELEASE)" >> $(SRC_RPMDIR)/.rpmmacros

.PHONY: build_rpm
build_rpm: conf/git_commit_id conf/build_id rpm/.rpmmacros dist-packetfence-test dist-packetfence-export dist-packetfence-upgrade dist
	cp $(SRC_RPMDIR)/.rpmmacros $(HOME)
	ci-build-pkg $(SRC_RPMDIR)/packetfence.spec
	# no need to build other packages if packetfence build failed
	ci-build-pkg $(SRC_RPMDIR)/packetfence-release.spec
	ci-build-pkg $(SRC_RPMDIR)/packetfence-test.spec
	ci-build-pkg $(SRC_RPMDIR)/packetfence-export.spec
	ci-build-pkg $(SRC_RPMDIR)/packetfence-upgrade.spec

.PHONY: build_deb
build_deb: conf/git_commit_id conf/build_id
	cp $(SRC_CIDIR)/debian/.devscripts $(HOME)
	QUILT_PATCHES=$(SRC_DEBDIR)/patches quilt push
	ci-build-pkg $(SRC_DEBDIR)

.PHONY: patch_release
patch_release:
	$(SRC_CIDIR)/lib/release/prep-release.sh

.PHONY: distclean
distclean: go_clean npm_clean clean
	rm -rf packetfence-$(PF_PATCH_RELEASE).tar

.PHONY: distclean-packetfence-test
distclean-packetfence-test:
	rm -rf packetfence-test-$(PF_PATCH_RELEASE).tar

.PHONY: go_clean
go_clean:
	$(MAKE) -C $(SRC_GODIR) clean

.PHONY: npm_clean
npm_clean:
	$(MAKE) -C $(SRC_HTML_COMMONDIR) clean
	$(MAKE) -C $(SRC_HTML_PFAPPDIR_ROOT) clean

.PHONY: dist
dist: distclean
	mkdir -p packetfence-$(PF_PATCH_RELEASE)
	# preserve, recursive and symlinks
	cp -pRH $(files_to_include) $(SRC_ROOT_DIR)/.dockerignore packetfence-$(PF_PATCH_RELEASE)
	tar c --exclude-from=$(SRC_ROOT_DIR)/dist_ignore \
	-f packetfence-$(PF_PATCH_RELEASE).tar packetfence-$(PF_PATCH_RELEASE)
	rm -rf packetfence-$(PF_PATCH_RELEASE)

.PHONY: dist-packefence-test
dist-packetfence-test: distclean-packetfence-test
	mkdir -p packetfence-test-$(PF_PATCH_RELEASE)
	# preserve, recursive and symlinks
	cp -pRH $(pf_test_files_to_include) packetfence-test-$(PF_PATCH_RELEASE)
	cp -p Makefile config.mk packetfence-test-$(PF_PATCH_RELEASE)
	tar c --exclude-from=$(SRC_ROOT_DIR)/dist_ignore \
	-f packetfence-test-$(PF_PATCH_RELEASE).tar packetfence-test-$(PF_PATCH_RELEASE)
	rm -rf packetfence-test-$(PF_PATCH_RELEASE)


# install -D will automatically create target directories
# SRC_RELATIVE_TESTDIR is used to only get relative paths from PF source tree
# $$file in destination of install command contain relative path
.PHONY: test_install
test_install:
	@echo "create directories under $(DESTDIR)$(TESTDIR)"
	install -d -m0755 $(DESTDIR)$(TESTDIR)

	@echo "install $(SRC_RELATIVE_TESTDIR) files"
	for file in $(shell find $(SRC_RELATIVE_TESTDIR) -type f); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(PF_PREFIX)/$$file ; \
	done

	@echo "install symlinks"
	for link in $(shell find $(SRC_RELATIVE_TESTDIR) -type l); do \
	    cp -v --no-dereference $$link $(DESTDIR)$(PF_PREFIX)/$$link ; \
	done

# -D to create target directories if they don't exist
.PHONY: pfconnector_remote_install
pfconnector_remote_install:
	install -v -d -m0750 $(DESTDIR)$(PFCONNECTOR_CONTAINERSDIR)
	install -v -d -m0750 $(DESTDIR)$(PFCONNECTOR_BINDIR)
	install -v -d -m0750 $(DESTDIR)$(PFCONNECTOR_PREFIX)/db
	# pfconnector-remote combined container
	install -v -D -m 0644 $(SRC_ROOT_DIR)/containers/pfconnector-remote/Dockerfile $(DESTDIR)$(PFCONNECTOR_CONTAINERSDIR)/pfconnector-remote/Dockerfile
	install -v -D -m 0755 $(SRC_PFCONNECTORDIR)/pfconnector-remote-combined-docker-wrapper $(DESTDIR)$(PFCONNECTOR_BINDIR)/pfconnector-remote-combined-docker-wrapper
	install -v -D -m 0644 $(SRC_PFCONNECTORDIR)/systemd/packetfence-pfconnector-remote-combined.service $(DESTDIR)/etc/systemd/system/packetfence-pfconnector-remote-combined.service
	install -v -D -m 0644 $(SRC_PFCONNECTORDIR)/containers/systemd-service $(DESTDIR)$(PFCONNECTOR_CONTAINERSDIR)/systemd-service
	install -v -D -m 0755 $(SRC_PFCONNECTORDIR)/containers/manage-images.sh $(DESTDIR)$(PFCONNECTOR_CONTAINERSDIR)/manage-images.sh
	TMPDIR=$(shell mktemp -d)
	touch $(TMPDIR)/pfconnector-client.env
	install -v -d -m0750 $(DESTDIR)$(PFCONNECTOR_CONFDIR)
	install -v -m 0600 $(TMPDIR)/pfconnector-client.env $(DESTDIR)$(PFCONNECTOR_CONFDIR)/pfconnector-client.env
	install -v -D -m 0755 $(SRC_PFCONNECTORDIR)/sync-radius-certs.sh $(DESTDIR)$(PFCONNECTOR_BINDIR)/sync-radius-certs.sh
	install -v -D -m 0755 $(SRC_PFCONNECTORDIR)/configure-raddb.sh $(DESTDIR)$(PFCONNECTOR_BINDIR)/configure-raddb.sh
	install -v -m 0755 $(SRC_PFCONNECTORDIR)/upgrade/remove-unpackaged-pfconnector.sh -D $(DESTDIR)$(PFCONNECTOR_UPGRADEDIR)/remove-unpackaged-pfconnector.sh
	install -v -m 0755 $(SRC_PFCONNECTORDIR)/configure.sh -D $(DESTDIR)$(PFCONNECTOR_BINDIR)/pfconnector-configure
	install -v -d -m0755 $(DESTDIR)/etc/docker
	install -v -m 0600 $(SRC_ROOT_DIR)/containers/daemon.json $(DESTDIR)/etc/docker/daemon.json
	install -v -m 0644 $(SRC_ROOT_DIR)/config.mk $(DESTDIR)$(PFCONNECTOR_PREFIX)/config.mk
	make -C $(SRC_GODIR) pfconnector
	install -v -m 0755 $(SRC_GODIR)/pfconnector $(DESTDIR)$(PFCONNECTOR_BINDIR)/pfconnector
	install -v -m 0644 $(SRC_CONFDIR)/build_id $(DESTDIR)$(PFCONNECTOR_CONFDIR)/build_id
	install -v -m 0644 $(SRC_CONFDIR)/pf-release $(DESTDIR)$(PFCONNECTOR_CONFDIR)/pf-release
	# raddb
	cp -rv $(SRC_ROOT_DIR)/raddb $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/auth.conf $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/auth.conf
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/clients.conf $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/clients.conf
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/proxy.conf.inc $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/proxy.conf.inc
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/radiusd.conf $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/radiusd.conf
	install -v -d -m0755 $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/mods-enabled
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/rest.conf $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/mods-enabled/rest
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/mschap.conf $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/mods-enabled/mschap
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/eap.conf $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/mods-enabled/eap
	rm -f $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/mods-enabled/perl
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/packetfence-pre-proxy $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/mods-config/attr_filter/packetfence-pre-proxy
	install -v -d -m0755 $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/sites-enabled
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/packetfence $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/sites-enabled/packetfence
	install -v -m 0644 $(SRC_PFCONNECTORDIR)/conf/radiusd/dynamic-clients $(DESTDIR)$(PFCONNECTOR_PREFIX)/raddb/sites-enabled/dynamic-clients

.PHONY: ntlm_auth_api_remote_install
ntlm_auth_api_remote_install:
	# logrotate config is installed through dh_installlogrotate
	install -v -d -m0750 $(DESTDIR)$(NTLM_AUTH_API_LOGDIR)
	install -v -d -m0750 $(DESTDIR)$(NTLM_AUTH_API_BINDIR)
	install -v -d -m0750 $(DESTDIR)$(NTLM_AUTH_API_SBINDIR)
	install -v -d -m0750 $(DESTDIR)$(NTLM_AUTH_API_CONFDIR)
	install -v -d -m0750 $(DESTDIR)$(NTLM_AUTH_API_UPGRADEDIR)
	install -v -d -m0755 $(DESTDIR)$(NTLM_AUTH_API_CONTAINERSDIR)
	install -v -d -m0755 $(DESTDIR)$(NTLM_AUTH_API_VARDIR)
	install -v -d -m0755 $(DESTDIR)$(NTLM_AUTH_API_VARDIR)/conf
	install -v -d -m0755 $(DESTDIR)$(NTLM_AUTH_API_VARDIR)/conf/ntlm-auth-api.d
	install -v -d -m0755 $(DESTDIR)$(NTLM_AUTH_API_VARDIR)/run

	@echo "install $(SRC_NTLM_AUTH_APIDIR) files"
	cd $(SRC_NTLM_AUTH_APIDIR) && for file in $$(find . -type f); do \
		install -v -m 0644 $$file -D $(DESTDIR)$(NTLM_AUTH_API_BINDIR)/$$file ; \
	done

	install -v -D -m 0755 $(SRC_NTLM_AUTH_API_ADDONSDIR)/ntlm-auth-api-domain $(DESTDIR)$(NTLM_AUTH_API_SBINDIR)/ntlm-auth-api-domain
	install -v -D -m 0755 $(SRC_NTLM_AUTH_API_ADDONSDIR)/ntlm-auth-api-monitor $(DESTDIR)$(NTLM_AUTH_API_SBINDIR)/ntlm-auth-api-monitor
	install -v -D -m 0755 $(SRC_NTLM_AUTH_API_ADDONSDIR)/ntlm-auth-api-docker-wrapper $(DESTDIR)$(NTLM_AUTH_API_SBINDIR)/ntlm-auth-api-docker-wrapper

	install -v -D -m 0644 $(SRC_NTLM_AUTH_API_ADDONSDIR)/systemd/packetfence-ntlm-auth-api-domain-remote@.service $(DESTDIR)/etc/systemd/system/packetfence-ntlm-auth-api-domain-remote@.service
	install -v -D -m 0644 $(SRC_NTLM_AUTH_API_ADDONSDIR)/systemd/packetfence-ntlm-auth-api-remote.service $(DESTDIR)/etc/systemd/system/packetfence-ntlm-auth-api-remote.service
	install -v -m 0644 $(SRC_NTLM_AUTH_API_ADDONSDIR)/containers/systemd-service $(DESTDIR)$(NTLM_AUTH_API_CONTAINERSDIR)/systemd-service
	install -v -m 0755 $(SRC_NTLM_AUTH_API_ADDONSDIR)/containers/manage-images.sh $(DESTDIR)$(NTLM_AUTH_API_CONTAINERSDIR)/manage-images.sh
	install -v -D -m 0644 $(SRC_ROOT_DIR)/containers/ntlm-auth-api/Dockerfile $(DESTDIR)$(NTLM_AUTH_API_CONTAINERSDIR)/ntlm-auth-api/Dockerfile
	install -v -d -m0755 $(DESTDIR)/etc/docker
	install -v -m 0600 $(SRC_ROOT_DIR)/containers/daemon.json $(DESTDIR)/etc/docker/daemon.json
	install -v -m 0644 $(SRC_ROOT_DIR)/config.mk $(DESTDIR)$(NTLM_AUTH_API_PREFIX)/config.mk

	install -v -D -m 0644 ${SRC_CONFDIR}/log.conf.d/ntlm-auth-api.conf.example $(DESTDIR)$(NTLM_AUTH_API_CONFDIR)/log.conf.d/ntlm-auth-api.conf

	install -v -m 0644 $(SRC_CONFDIR)/build_id $(DESTDIR)$(NTLM_AUTH_API_CONFDIR)/build_id
	install -v -m 0644 $(SRC_CONFDIR)/pf-release $(DESTDIR)$(NTLM_AUTH_API_CONFDIR)/pf-release
	make -C $(SRC_GODIR) sdnotify-proxy
	install -v -m 0755 $(SRC_GODIR)/sdnotify-proxy $(DESTDIR)$(NTLM_AUTH_API_SBINDIR)/sdnotify-proxy
	install -v -m 0755 $(SRC_NTLM_AUTH_API_ADDONSDIR)/pfconnector-remote-load.sh $(DESTDIR)$(NTLM_AUTH_API_BINDIR)/pfconnector-remote-load.sh

	TMPDIR=$(shell mktemp -d)
	touch $(TMPDIR)/ntlm_auth_api.env
	install -v -m 0600 $(TMPDIR)/ntlm_auth_api.env $(DESTDIR)$(NTLM_AUTH_API_CONFDIR)/ntlm_auth_api.env

.PHONY: ntlm_auth_join_remote_install
ntlm_auth_join_remote_install:
	# ntlm-auth-join shares the same prefix as ntlm-auth-api, so directories and shared files
	# are installed by ntlm_auth_api_remote_install (dependency: packetfence-ntlm-auth-api-remote)
	install -v -D -m 0755 $(SRC_NTLM_AUTH_API_ADDONSDIR)/ntlm-join-remote-docker-wrapper $(DESTDIR)$(NTLM_AUTH_JOIN_SBINDIR)/ntlm-join-remote-docker-wrapper
	install -v -D -m 0644 $(SRC_NTLM_AUTH_API_ADDONSDIR)/systemd/packetfence-ntlm-auth-join-remote.service $(DESTDIR)/etc/systemd/system/packetfence-ntlm-auth-join-remote.service
	install -v -D -m 0644 $(SRC_ROOT_DIR)/containers/ntlm-join-remote/Dockerfile $(DESTDIR)$(NTLM_AUTH_JOIN_CONTAINERSDIR)/ntlm-join-remote/Dockerfile

# install -D will automatically create target directories
# SRC_RELATIVE_CILIBDIR is used to only get relative paths from PF source tree
# $$file in destination of install command contain relative path
.PHONY: ci_lib_install
ci_lib_install:
	@echo "create directories under $(DESTDIR)$(CIDIR)"
	install -d -m0755 $(DESTDIR)$(CIDIR)
	install -d -m0755 $(DESTDIR)$(CILIBDIR)

	@echo "install $(SRC_RELATIVE_CILIBDIR) files"
	for file in $(shell find $(SRC_RELATIVE_CILIBDIR) -type f); do \
            install -v -m 0644 $$file -D $(DESTDIR)$(PF_PREFIX)/$$file ; \
	done

# packetfence-export package
.PHONY: distclean-packetfence-export
distclean-packetfence-export:
	rm -rf packetfence-export-$(PF_PATCH_RELEASE).tar

.PHONY: dist-packetfence-export
dist-packetfence-export: distclean-packetfence-export
	mkdir -p packetfence-export-$(PF_PATCH_RELEASE)
	# preserve, recursive and symlinks
	cp -pRH $(pf_export_files_to_include) packetfence-export-$(PF_PATCH_RELEASE)
	tar c --exclude-from=$(SRC_ROOT_DIR)/dist_ignore \
	-f packetfence-export-$(PF_PATCH_RELEASE).tar packetfence-export-$(PF_PATCH_RELEASE)
	rm -rf packetfence-export-$(PF_PATCH_RELEASE)

# packetfence-upgrade package
.PHONY: distclean-packetfence-upgrade
distclean-packetfence-upgrade:
	rm -rf packetfence-upgrade-$(PF_PATCH_RELEASE).tar

.PHONY: dist-packetfence-upgrade
dist-packetfence-upgrade: distclean-packetfence-upgrade
	mkdir -p packetfence-upgrade-$(PF_PATCH_RELEASE)
	# preserve, recursive and symlinks
	cp -pRH $(pf_upgrade_files_to_include) packetfence-upgrade-$(PF_PATCH_RELEASE)
	tar c --exclude-from=$(SRC_ROOT_DIR)/dist_ignore \
	-f packetfence-upgrade-$(PF_PATCH_RELEASE).tar packetfence-upgrade-$(PF_PATCH_RELEASE)
	rm -rf packetfence-upgrade-$(PF_PATCH_RELEASE)

.PHONY: website
website:
	$(SRC_CIDIR)/lib/release/publish-to-website.sh

.PHONY: material
material: DESTDIR=result
material:
	mkdir -p $(CURDIR)/$(DESTDIR)
	perl $(SRC_ADDONSDIR)/dev-helpers/bin/switch_options_json.pl > $(CURDIR)/$(DESTDIR)/switches.json

html/captive-portal/profile-templates/default/logo.png:
	mkdir -p html/captive-portal/profile-templates/default
	cp html/common/packetfence-cp.png /usr/local/pf/html/captive-portal/profile-templates/default/logo.png


