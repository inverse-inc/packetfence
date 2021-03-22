# pfdhcplistener_multi_tenant

## Requirements
- Configurator test passed with portal on management interface.
- TODO: install perl-Net-DHCP (packetfence-devel) and libnet-dhcp-perl
  packages
- TODO: install dhcp-test script on PF server (currently missing)

## Global config steps
A tenant different than default has been configured (see
global_config_multi_tenant scenario)

## Scenario steps

### Mono-tenant
1. Create a production network in new tenant
1. Restart services (iptables, pfdhcp, pfdns, pfdhcplistener)
1. Create a DHCP request from an unknown node using `dhcp-test` tool
1. Check node created in DB
1. Check current ip4log of node created in DB
1. Create a DHCP request from previous node using `dhcp-test` tool with new IP
1. Check `last_seen` and `last_dhcp` attribute updated in DB 
1. Check new ip4log of node created in DB

## Teardown steps
1. Remove node from DB
1. Remove production network


## Additional notes

- `dhcp-test` send a DHCP REQUEST and ACK on interface where default route is
  defined. Source IP address in these two messages is interface IP address.
