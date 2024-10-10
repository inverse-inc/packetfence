# dot1x_eap_peap_firewall_sso_https

## Requirements
AD server running

## Global config steps
1. Create access duration
1. Create dot1x roles
1. Create switches and switch groups

## Scenario steps
1. Enable node_cleanup task with following parameters:
- delete_windows=1m
1. Restart `pfcron` to take change into account
1. Create HTTPS mock with Smocker HTTP mock and haproxy SSL termination
1. Create Firewall SSO
1. Enable SSO in base advanced configuration with the following parameters:
- sso_on_access_reevaluation: enabled
1. Restart `pfsso` to take change into account
1. Join domain
1. Configure REALMS
1. Restart RADIUS services (common test suite)
1. Create and test AD sources
1. Create connection profile with auto-registration, AD sources, specific
   filter and `unreg_on_accounting_stop`
1. Perform Checkup (common test suite)
1. Configure 802.1X only and dynamic VLAN on dot1x interface on
   switch01
1. Start wpa_supplicant *on* node01
1. Wait some time to let RADIUS request be sent by switch01 and handled by
   PacketFence server
1. Check RADIUS audit log for node01
1. Check HTTPS mock for Firewall SSO Start
1. Check node status for node01
1. Check VLAN assigned to node01 *on* switch01
1. Check Internet access *on* node01
1. Deregister node01 to force Firewall SSO Stop
1. Check HTTPS mock for Firewall SSO Stop

## Teardown steps
1. Check node unregistration
1. Kill wpa_supplicant: an accounting stop will be generated if we wait
   EAP-TIMEOUT on the switch (not the case here due to next task). Access is
   still working until we run next task.
1. Unconfigure switch port and dynamic VLAN on switch01
   1. Generate a RADIUS Accounting stop message (sent by switch01) which update
      `last_seen` attribute of node01 and unreg device based on
      `unreg_on_accounting_stop`
   1. Don't send a RADIUS Disconnect message
1. Wait `delete_windows` + 10 seconds before running `node_cleanup` task
1. Delete node by running `pfcron's node_cleanup` task
1. Check node has been deleted
1. Restart interface on node01 to:
  * release DHCP lease
  * restart DHCP client for next tests
1. Disable `node_cleanup` task
1. Restart `pfcron` to take change into account
1. Delete Firewall SSO
1. Disable SSO in base advanced configuration with the following parameters:
- sso_on_access_reevaluation: disabled
1. Restart `pfsso` to take change into account
1. Kill HTTPS mock
1. Unconfigure and delete REALMS
1. Delete domain
1. Delete connection profile
1. Delete sources
1. Stop NTLM Auth API service
1. Restart RADIUS services (common test suite)

## Additional notes

Accounting sent by Cumulus switch is not used to trigger firewall SSO workflow
because RADIUS accounting message don't include IP addresses of devices.

Trigger of SSO Start is done using DHCP request on production VLAN.  Trigger
of SSO Stop is possible thanks to SSO on access reevaluation. We trigger it
using API when we deregister node. It's not possible to trigger a SSO stop
only with a reevaluate acess when node is registered.
