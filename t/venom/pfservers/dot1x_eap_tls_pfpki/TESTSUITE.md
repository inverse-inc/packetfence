# dot1x_eap_tls_pfpki

## Requirements
N/A

### Global config steps
1. Create dot1x_eap_tls role

## Scenario steps
1. Create Root CA
1. Create user certificate template
1. Create RADIUS server certificate template
1. Create Web server certificate template
1. Generate RADIUS server certificate to be used by RADIUS services
1. Generate Web server certificate to be used by web admin and captive portal
1. Generate user certificate to be used by node01 with EAP-TLS
1. Install Root CA + RADIUS server certificates (public certificate and
   private key) on PacketFence
1. Configure OCSP
1. Restart radiusd services (common test suites)
1. Install Root CA + Web server certificates (public certificate and private key) on PacketFence
1. Restart web services (only haproxy-portal and haproxy-admin)
1. Create EAPTLS source with conditions (Server-common-name) on user certificate that assign
   dot1x_eap_tls 
1. Create connection profile with auto-registration, unreg_on_accounting_stop,
   EAPTLS source and specific
   filter
1. Perform Checkup (common test suite)

TODO:
1. Configure 802.1X only and dynamic VLAN on dot1x interface on
   switch01
1. Install Root CA on node01 
1. Install user certificates (public certificate and private key) on node01
   with following paths:
   - ca_cert: /etc/wpa_supplicant/eap_tls/ca.pem
   - client_cert: /etc/wpa_supplicant/eap_tls/client.pem
   - private_key: /etc/wpa_supplicant/eap_tls/client.key
1. Start wpa_supplicant *on* node01 with eap_tls configuration
1. Check RADIUS audit log for node01 (common)
1. Check node status for node01 (common)
1. Check VLAN assigned to node01 *on* switch01 (common)
1. Check Internet access *on* node01 (common)
1. Revoke certificate
1. Kill wpasupplicant (common test suite)
1. Rerun wpasupplicant to have a reject authentication due to revoke certificate
1. Check RADIUS audit log for node01 (common) = reject
1. Check node status for node01 (common) = registered
1. Check VLAN assigned to node01 *on* switch01 (common) = NOT AUTHORIZED
1. Check Internet access *on* node01 (common) = down

## Teardown steps
TBD but identical to dot1x_eap_peap scenario (based on unreg_on_accounting_stop)

Revoke certificates to avoid issues when you try to create a certificate that
already exists

Name of CA, templates and certificates should be uniq. Not possible to revoke
or remove CA or template.
