# security_event_autoreg

Test that the triggering a security event on DHCP fingerprint to autoreg a device works

## Requirements

## Scenario steps
1. Create the autoreg security event with a trigger on the DHCP fingerprint of node01
1. Create a connection profile
1. Enable MAB+802.1x and dynamic VLAN assignment on the switchport of node01
1. node01 will connect and get autoregistered
1. Validate that the access duration of node01 is accurate
1. Validate that node01 has internet access (i.e. was successfully registered)

## Teardown steps
1. Disable 802.1x+MAB on the switchport of node01
1. Delete node01
1. Delete the connection profile that was created
1. Delete the autoreg security event

