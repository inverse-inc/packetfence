# captive_portal

Put a node on registration VLAN to test some captive portal features.

## Requirements

### Global config steps
1. Create switches and switch groups with default role mapping

## Scenario steps
1. Create connection profile with specific filter Ethernet-NoEAP
1. Configure MAC authentication and dynamic VLAN on dot1x interface on
   switch01: will trigger a RADIUS request
1. Wait some time to let RADIUS request be sent by switch01 and handled by
   PacketFence server (`mab_activation_delay` + 20 seconds). switch01 also needs to handle answer.
1. Check RADIUS audit log for node01
1. Check VLAN assigned to node01 *on* switch01
1. Wait some time to let node01 received an IP through DHCP
1. Run locales test *on* node01

## Teardown steps
1. Unconfigure switch port and dynamic VLAN on switch01
   1. Generate a RADIUS Accounting stop message (sent by switch01) which update
      `last_seen` attribute of node01
1. Delete node through API
1. Check node has been deleted
1. Delete connection profile
1. Clean httpd.portal cache
