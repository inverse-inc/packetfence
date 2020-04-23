# wired_mac_auth

Register a node with RADIUS in order to test MAC Authentication on Wired
## Requirements

### Switch side
1. Configure accounting

### Global config steps
1. Create a role headless_device
1. Create switches and switch groups with role mapping

## Scenario steps
1. Enable node_cleanup task with following parameters:
- delete_windows=1M
1. Create a node with MAC address of node01 (eth1) : 00:03:00:11:11:01
- set a short unregdate
- assign the role headless_device
- add a notes
1. Create connection profile with specific filter Ethernet-NoEAP and unreg_on_accounting_stop
1. Send a MAC Auth RADIUS request to PacketFence from switch01
1. Check RADIUS audit log for node01
1. Check data received from accounting: Start
1. Check VLAN assigned to node01 *on* switch01
1. Check Internet access *on* node01

## Teardown steps
1. Send a RADIUS accounting stop request from switch01 to PacketFence in order
   to close locationlog => ifdown
1. Verify that node is unregistered
1. Verify that latest locationlog is closed
1. Delete node by running pfmon node_cleanup
1. Check node has been deleted
1. Disable node_cleanup task
1. Delete connection profile
