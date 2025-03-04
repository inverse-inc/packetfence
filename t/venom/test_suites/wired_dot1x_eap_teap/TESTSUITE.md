# dot1x_eap_peap

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
1. Check node status for node01
1. Check VLAN assigned to node01 *on* switch01
1. Check Internet access *on* node01

## Teardown steps
1. Kill wpa_supplicant: an accounting stop will be generated if we wait
   EAP-TIMEOUT on the switch (not the case here due to next task). Access is
   still working until we run next task.
1. Unconfigure switch port and dynamic VLAN on switch01
   1. Generate a RADIUS Accounting stop message (sent by switch01) which update
      `last_seen` attribute of node01 and unreg device based on
      `unreg_on_accounting_stop`
   1. Don't send a RADIUS Disconnect message
1. Check online status of node01: should be offline due to accounting stop
1. Check node status for node01
1. Wait `delete_windows` + 10 seconds before running `node_cleanup` task
1. Delete node by running `pfcron's node_cleanup` task
1. Check node has been deleted
1. Disable `node_cleanup` task
1. Restart `pfcron` to take change into account
1. Unconfigure and delete REALMS
1. Delete domain
1. Delete connection profile
1. Delete sources
1. Stop NTLM Auth API service
1. Restart RADIUS services (common test suite)

## Additional notes

Reauthentication is done by switch based on `eap_reauth_period` setting to
avoid node been unregistered when it reach unregdate and automatically deleted
by `pfcron` without running teardown steps.
