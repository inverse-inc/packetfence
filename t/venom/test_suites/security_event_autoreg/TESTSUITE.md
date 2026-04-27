# security_event_autoreg

Test that the triggering a security event on DHCP fingerprint to autoreg a device works

## Requirements

## Scenario steps

### Prepare
1. Create the autoreg security event with a trigger on the DHCP fingerprint of node01
1. Create a connection profile
1. Enable MAB+802.1x and dynamic VLAN assignment on the switchport of node01
1. Commit changes in configuration

### Verify
5. Run verification tests (node01 connects, gets autoregistered, access
   duration is accurate, node01 has internet access)

## Teardown steps
1. Disable MAC authentication on the switchport of node01
1. Disable dynamic VLAN on switch01
1. Commit changes in configuration
1. Delete node01
1. Delete the connection profile that was created
1. Delete the autoreg security event

