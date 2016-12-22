all:
	@echo "Please chose which documentation to build:"
	@echo ""
	@echo " 'pdf' will build all guide using the PDF format"
	@echo " 'PacketFence_Administration_Guide.pdf' will build the Administration guide in PDF"
	@echo " 'PacketFence_Developers_Guide.pdf' will build the Develoeprs guide in PDF"
	@echo " 'PacketFence_Network_Devices_Configuration_Guide.pdf' will build the Network Devices Configuration guide in PDF"

pdf: $(patsubst %.asciidoc,%.pdf,$(notdir $(wildcard docs/PacketFence_*.asciidoc)))

%.pdf : docs/%.asciidoc
	asciidoc \
		-a docinfo2 \
		-b docbook \
		-d book \
		-o docs/docbook/$(notdir $<).docbook \
		$<
	 fop \
		-c docs/fonts/fop-config.xml \
		-xsl docs/docbook/xsl/packetfence-fo.xsl \
		-xml docs/docbook/$(notdir $<).docbook \
		-pdf docs/$@

html: $(patsubst %.asciidoc,%.html,$(notdir $(wildcard docs/PacketFence_*.asciidoc)))

%.html : docs/%.asciidoc
	asciidoctor \
		-D docs/html \
		-n \
		$<

pfcmd.help:
	/usr/local/pf/bin/pfcmd help > docs/pfcmd.help

.PHONY: configurations

configurations:
	find -type f -name '*.example' -print0 | while read -d $$'\0' file; do cp -n $$file "$$(dirname $$file)/$$(basename $$file .example)"; done
	touch /usr/local/pf/conf/pf.conf

.PHONY: ssl-certs

conf/ssl/server.crt:
	openssl req -x509 -new -nodes -days 365 -batch \
	-out /usr/local/pf/conf/ssl/server.crt \
	-keyout /usr/local/pf/conf/ssl/server.key \
	-nodes -config /usr/local/pf/conf/openssl.cnf

conf/pf_omapi_key:
	/usr/bin/openssl rand -base64 -out /usr/local/pf/conf/pf_omapi_key 32

conf/local_secret:
	date +%s | sha256sum | base64 | head -c 32 > /usr/local/pf/conf/local_secret

bin/pfcmd: src/pfcmd.c
	$(CC) -O2 -g -std=c99  -Wall $< -o $@

bin/ntlm_auth_wrapper: src/ntlm_auth_wrap.c
	cc -g -std=c99  -Wall  src/ntlm_auth_wrap.c -o bin/ntlm_auth_wrapper

.PHONY:permissions

/etc/sudoers.d/packetfence.sudoers: packetfence.sudoers
	cp packetfence.sudoers /etc/sudoers.d/packetfence.sudoers

.PHONY:sudo

sudo:/etc/sudoers.d/packetfence.sudoers


permissions:
	./bin/pfcmd fixpermissions

raddb/certs/server.crt:
	cd raddb/certs; make

.PHONY: raddb-sites-enabled

raddb/sites-enabled:
	mkdir raddb/sites-enabled
	cd raddb/sites-enabled;\
	for f in packetfence packetfence-soh packetfence-tunnel dynamic-clients;\
		do ln -s ../sites-available/$$f $$f;\
	done

.PHONY: translation

translation:
	for TRANSLATION in de en es fr he_IL it nl pl_PL pt_BR; do\
		/usr/bin/msgfmt conf/locale/$$TRANSLATION/LC_MESSAGES/packetfence.po\
		  --output-file conf/locale/$$TRANSLATION/LC_MESSAGES/packetfence.mo;\
	done

.PHONY: mysql-schema

mysql-schema:
	ln -f -s /usr/local/pf/db/pf-schema-X.Y.Z.sql /usr/local/pf/db/pf-schema.sql;
	ln -f -s /usr/local/pf/db/pf_graphite-schema-5.1.0.sql /usr/local/pf/db/pf_graphite-schema.sql

.PHONY: chown_pf

chown_pf:
	chown -R pf:pf *

.PHONY: fingerbank

fingerbank:
	rm -f /usr/local/pf/lib/fingerbank
	ln -s /usr/local/fingerbank/lib/fingerbank /usr/local/pf/lib/fingerbank \

devel: configurations conf/ssl/server.crt conf/pf_omapi_key conf/local_secret bin/pfcmd raddb/certs/server.crt sudo translation mysql-schema raddb/sites-enabled fingerbank chown_pf permissions bin/ntlm_auth_wrapper 
