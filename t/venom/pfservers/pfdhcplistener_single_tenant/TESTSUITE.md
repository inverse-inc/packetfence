# pfdhcplistener_single_tenant

## Requirements
- Configurator test passed with portal on management interface.
- TODO: install perl-Net-DHCP (packetfence-devel) and libnet-dhcp-perl
  packages
- TODO: install dhcp-test script on PF server (currently missing)

## Global config steps


## Scenario steps

### Mono-tenant
1. Create a DHCP request from an unknown node using `dhcp-test` tool
1. Check node created in DB
1. Check current ip4log of node created in DB
1. Create a DHCP request from previous node using `dhcp-test` tool with *new* IP
1. Check `last_seen` and `last_dhcp` attribute updated in DB 
1. Check new ip4log of node created in DB

## Teardown steps
1. Remove node from DB
