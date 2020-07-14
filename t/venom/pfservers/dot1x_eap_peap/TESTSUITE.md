# dot1x_eap_peap

## Requirements
AD server running

### Global config steps
1. Create access duration
1. Create dot1x roles
1. Create switches and switch groups

## Scenario steps
1. Enable node_cleanup task with following parameters:
- delete_windows=1m
1. Restart `pfmon` to take change into account
1. Join domain
1. Configure REALMS
1. Restart RADIUS services (common test suite)
1. Create and test AD sources
1. [X] Create connection profile with auto-registration, AD sources, specific
   filter and `unreg_on_accounting_stop`
1. Perform Checkup (common test suite)
1. Configure 802.1X only and dynamic VLAN on dot1x interface on
   switch01
1. Start wpa_supplicant *on* node01
1. Wait some time to let RADIUS request be sent by switch01 and handled by
   PacketFence server
1. [ ] Check RADIUS audit log for node01 (filter on eap-peap)
1. [/] Check node status for node01
   1. [/] reg
   1. [/] role
   1. [ ] Check unregdate value
1. [X] Check VLAN assigned to node01 *on* switch01
1. [X] Check Internet access *on* node01

## Teardown steps
1. [X] Kill wpa_supplicant: doesn't generate an accounting stop and doesn't
       shut down access
1. [X] Unconfigure switch port and dynamic VLAN on switch01
   1. Generate a RADIUS Accounting stop message (sent by switch01) which update
      `last_seen` attribute of node01 and unreg device based on
      `unreg_on_accounting_stop`
   1. Don't send a RADIUS Disconnect message
1. [ ] Check node status for node01
   1. [ ] unregistered
1. [/] Wait `delete_windows` + 10 seconds before running `node_cleanup` task
1. [/] Delete node by running `pfmon's node_cleanup` task
1. [/] Check node has been deleted
1. Disable `node_cleanup` task
1. Restart `pfmon` to take change into account
1. Unconfigure and delete REALMS
1. Delete domain
1. Delete connection profile
1. Delete sources
1. Restart RADIUS services (common test suite)

