# wired_dot1x_eap_peap_firewall_sso_radius

Almost identical to wired_dot1x_eap_peap_firewall_sso_https. Difference:
 * we used node03 in place of node01
 * SSO is sent to firewall using RADIUS

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
1. Create RADIUS mock for Firewall SSO
1. Create Firewall SSO
1. Enable SSO on access reevaluation and accounting
1. Restart `pfsso` to take change into account
1. Join domain
1. Configure REALMS
1. Restart RADIUS services (common test suite)
1. Create and test AD machine source
1. Create and test AD user source
1. Create connection profile with auto-registration, AD sources, specific
   filter and `unreg_on_accounting_stop`
1. Delete iptable rule
1. Enable 802.1X only on dot1x interface (node03) on switch01
1. Enable dynamic VLAN on switch01
1. Commit changes in configuration
1. Run wpa_supplicant on node03
1. Check RADIUS audit log
1. Check Firewall SSO Start
1. Check autoregister node
1. Check dot1x interface status on switch01
1. Check internet access on node03
1. Deregister node to force SSO on reevaluation
1. Check Firewall SSO Stop

## Teardown steps
1. Check node unregistration
1. Kill wpa_supplicant on node03
1. Disable 802.1X on dot1x interface (node03) on switch01
1. Disable dynamic VLAN on switch01
1. Commit changes in configuration
1. Wait `delete_windows` + 10 seconds before running `node_cleanup` task
1. Delete node03 by running `pfcron's node_cleanup` task
1. Check if node03 has been correctly deleted
1. Release DHCP on node03
1. Disable `node_cleanup` task
1. Restart `pfcron` to take change into account
1. Delete Firewall SSO
1. Disable SSO on access reevaluation and accounting
1. Restart `pfsso` to take change into account
1. Kill RADIUS mock
1. Stop NTLM Auth API service
1. Delete REALMS, domain, connection profile, sources
1. Restart RADIUS services (common test suite)
1. Reload iptables rules

## Additional notes

Accounting sent by Cumulus switch is not used to trigger firewall SSO workflow
because RADIUS accounting message don't include IP addresses of devices.

Trigger of SSO Start is done using DHCP request on production VLAN. Trigger
of SSO Stop is possible thanks to SSO on access reevaluation. We trigger it
using API when we deregister node. It's not possible to trigger a SSO stop
only with a reevaluate access when node is registered.
