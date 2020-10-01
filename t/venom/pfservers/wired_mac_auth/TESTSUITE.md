# wired_mac_auth

Register a node with RADIUS in order to test MAC Authentication on Wired

## Requirements

### Global config steps
1. Create a role headless_device
1. Create switches and switch groups with role mapping

## Scenario steps
1. Enable node_cleanup task with following parameters:
- delete_windows=1m
1. Restart `pfcron` to take change into account
1. Create a node with MAC address of node01 (eth1) : 00:03:00:11:11:01
- assign the role headless_device without unreg date
- add a note
1. Create connection profile with specific filter Ethernet-NoEAP
1. Configure MAC authentication and dynamic VLAN on dot1x interface on
   switch01: will trigger a RADIUS request
1. Wait some time to let RADIUS request be sent by switch01 and handled by
   PacketFence server
1. Check RADIUS audit log for node01
1. Check VLAN assigned to node01 *on* switch01
1. Check Internet access *on* node01

## Teardown steps
1. Unregister node01:
   1. Generate a disconnect message
   1. Generate a RADIUS Accounting stop message (sent by switch01) which update
      `last_seen` attribute of node01
   1. Generate a new RADIUS request (sent by switch01) which update
      `last_seen` attribute of node01
   1. Generate a RADIUS Accounting start message (sent by switch01) which update
      `last_seen` attribute of node01
1. Wait some time before unconfigure switch01 to avoid a Disconnect-NAK
1. Unconfigure switch port and dynamic VLAN on switch01
   1. Generate a RADIUS Accounting stop message (sent by switch01) which update
      `last_seen` attribute of node01
1. Wait `delete_windows` + 10 seconds before running `node_cleanup` task
1. Delete node by running `pfcron's node_cleanup` task
1. Check node has been deleted
1. Disable `node_cleanup` task
1. Restart `pfcron` to take change into account
1. Delete connection profile
