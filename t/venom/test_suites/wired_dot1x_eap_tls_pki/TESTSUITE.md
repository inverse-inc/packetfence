# wired_dot1x_eap_tls_pki

## Requirements
N/A

### Global config steps

## Scenario steps
1. Enable node_cleanup task with following parameters:
- delete_windows=1m
1. Restart `pfcron` to take change into account
1. Create Root CA
1. Create RADIUS server certificate template
1. Create Web server certificate template
1. Create user certificate template
1. Generate RADIUS server certificate to be used by RADIUS services
1. Generate Web server certificate to be used by web admin and captive portal
1. Generate user certificate to be used by node01 with EAP-TLS
1. Install Root CA + RADIUS server certificates (public certificate and
   private key) on PacketFence
1. Install Root CA + Web server certificates (public certificate and private key) on PacketFence
1. Configure OCSP to check certificate revocation against pfpki
1. Create and test AD source
1. Restart radiusd services
1. Restart web services (only haproxy-portal and haproxy-admin)
1. Create connection profile with auto-registration, AD source, specific
   filter and `unreg_on_accounting_stop`
1. Perform Checkup (common test suite)
1. Configure 802.1X only and dynamic VLAN on dot1x interface on
   switch01
1. Install Root CA on node01
1. Install user certificates (public certificate and private key) on node01
   with following paths:
   - ca_cert: /etc/wpa_supplicant/eap_tls/ca.pem
   - client_cert: /etc/wpa_supplicant/eap_tls/client.pem
   - private_key: /etc/wpa_supplicant/eap_tls/client.key
1. Start eapol_test on host with eap_tls configuration
1. Check RADIUS audit log for node01
1. Check eapol_test log
1. Create accounting
1. Check node status for node01
1. Check if node is online

## Teardown steps
1. Stop accounting
1. Check if node01 is offline
1. Check unregistered node
1. Wait `delete_windows` + 10 seconds before running `node_cleanup` task
1. Delete node by running `pfcron's node_cleanup` task
1. Check node has been deleted
1. Disable `node_cleanup` task
1. Restart `pfcron` to take change into account
1. Clean PKI tables
1. Delete connection profile, source, OCSP profile and configuration
1. Restart RADIUS services

## Additional notes

Reauthentication is done by switch based on `eap_reauth_period` setting to
avoid node been unregistered when it reach unregdate and automatically deleted
by `pfcron` without running teardown steps.
