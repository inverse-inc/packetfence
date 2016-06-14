all:
	@echo "Please chose which documentation to build:"
	@echo ""
	@echo " 'pdf' will build all guide using the PDF format"
	@echo " 'doc-admin-pdf' will build the Administration guide in PDF"
	@echo " 'doc-developers-pdf' will build the Develoeprs guide in PDF"
	@echo " 'doc-networkdevices-pdf' will build the Network Devices Configuration guide in PDF"

pdf: doc-admin-pdf doc-developers-pdf doc-networkdevices-pdf doc-opswat-pdf doc-mobileiron-pdf doc-sepm-pdf doc-paloalto-pdf doc-barracuda-pdf doc-fortigate-pdf doc-opendaylight-pdf doc-checkpoint-pdf

doc-admin-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Administration_Guide.docbook docs/PacketFence_Administration_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Administration_Guide.docbook  -pdf docs/PacketFence_Administration_Guide.pdf

doc-developers-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Developers_Guide.docbook docs/PacketFence_Developers_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Developers_Guide.docbook  -pdf docs/PacketFence_Developers_Guide.pdf

doc-mobileiron-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_MobileIron_Quick_Install_Guide.docbook docs/PacketFence_MobileIron_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_MobileIron_Quick_Install_Guide.docbook  -pdf docs/PacketFence_MobileIron_Quick_Install_Guide.pdf

doc-networkdevices-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Network_Devices_Configuration.docbook docs/PacketFence_Network_Devices_Configuration_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Network_Devices_Configuration.docbook -pdf docs/PacketFence_Network_Devices_Configuration.pdf

doc-opswat-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_OPSWAT_Quick_Install_Guide.docbook docs/PacketFence_OPSWAT_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_OPSWAT_Quick_Install_Guide.docbook  -pdf docs/PacketFence_OPSWAT_Quick_Install_Guide.pdf

doc-sepm-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_SEPM_Quick_Install_Guide.docbook docs/PacketFence_SEPM_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_SEPM_Quick_Install_Guide.docbook  -pdf docs/PacketFence_SEPM_Quick_Install_Guide.pdf

doc-anyfi-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Anyfi_Quick_Install_Guide.docbook docs/PacketFence_Anyfi_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Anyfi_Quick_Install_Guide.docbook -pdf docs/PacketFence_Anyfi_Quick_Install_Guide.pdf

doc-paloalto-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_PaloAlto_Quick_Install_Guide.docbook docs/PacketFence_PaloAlto_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_PaloAlto_Quick_Install_Guide.docbook  -pdf docs/PacketFence_PaloAlto_Quick_Install_Guide.pdf

doc-fortigate-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_FortiGate_Quick_Install_Guide.docbook docs/PacketFence_FortiGate_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_FortiGate_Quick_Install_Guide.docbook  -pdf docs/PacketFence_FortiGate_Quick_Install_Guide.pdf

doc-barracuda-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Barracuda_Quick_Install_Guide.docbook docs/PacketFence_Barracuda_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Barracuda_Quick_Install_Guide.docbook  -pdf docs/PacketFence_Barracuda_Quick_Install_Guide.pdf

doc-opendaylight-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_OpenDaylight_Install_Guide.docbook docs/PacketFence_OpenDaylight_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_OpenDaylight_Install_Guide.docbook  -pdf docs/PacketFence_OpenDaylight_Install_Guide.pdf

doc-checkpoint-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Checkpoint_Quick_Install_Guide.docbook docs/PacketFence_Checkpoint_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Checkpoint_Quick_Install_Guide.docbook  -pdf docs/PacketFence_Checkpoint_Quick_Install_Guide.pdf

doc-clustering-pdf:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Clustering_Guide.docbook docs/PacketFence_Clustering_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Clustering_Guide.docbook  -pdf docs/PacketFence_Clustering_Guide.pdf

doc-out-of-band-zen:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Out-of-Band_Deployment_Quick_Guide_ZEN.docbook docs/PacketFence_Out-of-Band_Deployment_Quick_Guide_ZEN.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Out-of-Band_Deployment_Quick_Guide_ZEN.docbook  -pdf docs/PacketFence_Out-of-Band_Deployment_Quick_Guide_ZEN.pdf

doc-inline-zen:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_Inline_Deployment_Quick_Guide_ZEN.docbook docs/PacketFence_Inline_Deployment_Quick_Guide_ZEN.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_Inline_Deployment_Quick_Guide_ZEN.docbook  -pdf docs/PacketFence_Inline_Deployment_Quick_Guide_ZEN.pdf

doc-openwrt-hostapd:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_OpenWrt-Hostapd_Quick_Install_Guide.docbook docs/PacketFence_OpenWrt-Hostapd_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_OpenWrt-Hostapd_Quick_Install_Guide.docbook  -pdf docs/PacketFence_OpenWrt-Hostapd_Quick_Install_Guide.pdf

doc-pki:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_PKI_Quick_Install_Guide.docbook docs/PacketFence_PKI_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_PKI_Quick_Install_Guide.docbook  -pdf docs/PacketFence_PKI_Quick_Install_Guide.pdf

doc-mspki:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_MSPKI_Quick_Install_Guide.docbook docs/PacketFence_MSPKI_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_MSPKI_Quick_Install_Guide.docbook  -pdf docs/PacketFence_MSPKI_Quick_Install_Guide.pdf

doc-aerohive:
	asciidoc -a docinfo2 -b docbook -d book -d book -o docs/docbook/PacketFence_AeroHIVE_Quick_Install_Guide.docbook docs/PacketFence_AeroHIVE_Quick_Install_Guide.asciidoc; fop -c docs/fonts/fop-config.xml   -xsl docs/docbook/xsl/packetfence-fo.xsl -xml docs/docbook/PacketFence_AeroHIVE_Quick_Install_Guide.docbook  -pdf docs/PacketFence_AeroHIVE_Quick_Install_Guide.pdf

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

raddb/certs:
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

devel: configurations conf/ssl/server.crt conf/pf_omapi_key conf/local_secret bin/pfcmd raddb/certs sudo translation mysql-schema raddb/sites-enabled fingerbank chown_pf permissions bin/ntlm_auth_wrapper
