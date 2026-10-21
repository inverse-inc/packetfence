# Inline L2 and RADIUS

## Requirements

Configurator_inline_l2

## Scenario steps

1. Role and switch are defined in global config

We don't assign VLAN because we just want to receive an ACCEPT to get access
on Inline network

1. Configure Inline L2 interface and network
1. Restart services
1. Create node01 and register node01
1. Create connection profile with specific filter Ethernet-NoEAP
1. Enable MAC authentication on dot1x interface on switch01
1. Enable dynamic VLAN on switch01
1. Commit changes in configuration
1. Check RADIUS audit log

## Teardown steps
1. Delete connection profile

### Additional notes


