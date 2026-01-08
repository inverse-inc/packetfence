# wired_mac_auth_virtualswitch

Test MAC Authentication using VirtualSwitch running on a separate Linux VM.

## Overview

This test suite uses virtualswitch running on a dedicated VM (`virtualswitch01`) to simulate
a network switch for MAC authentication testing. The virtualswitch VM connects to the
existing registration network from vagrant.

## Architecture

```
+---------------------------+     +---------------------------+
|         PF VM             |     |    virtualswitch01 VM     |
|                           |     |                           |
|  +---------------------+  |     |  +---------------------+  |
|  |  PacketFence        |  |     |  |  VirtualSwitch      |  |
|  |                     |  |     |  |                     |  |
|  |  Admin API: :1443   |  |     |  |  REST API: :8080    |  |
|  |  RADIUS: :1812      |<-+-----+->|  Simulated devices  |  |
|  |  DHCP               |  |     |  |  RADIUS client      |  |
|  +---------------------+  |     |  +---------------------+  |
|                           |     |                           |
|  Registration Network     |     |  Registration Network     |
|  (from vagrant inventory) |     |  (DHCP from PF or static) |
+---------------------------+     +---------------------------+
            |                                   |
            +---------------+-------------------+
                            |
                  Registration Network
            (from vagrant inventory, e.g., 172.18.X+1.0/24)
```

## Key Benefits

- **Reduced VMs**: Only 2 VMs (PF + virtualswitch01) instead of 4 (PF + switch01 + node01 + wireless01)
- **Internet access testable**: Can verify internet access from the virtualswitch VM
- **Simpler than Cumulus**: No need for Cumulus VX switch simulation
- **Realistic network path**: VirtualSwitch VM connects like a real switch/client

## Requirements

### Global config steps
1. Create a role `headless_device`
2. Create a role `printer` (for Fingerbank tests)
3. Create switches and switch groups with role mapping

## Network Setup

The virtualswitch01 VM connects to the **existing registration network** defined in vagrant inventory:
- No additional network configuration needed on PF
- VirtualSwitch uses the registration network IP for RADIUS communication
- PF's existing registration interface handles DHCP and RADIUS

## Test Flow

### Basic MAC Auth Test
1. Install virtualswitch package (pre-provisioned via Ansible)
2. Configure virtualswitch with RADIUS pointing to PF
3. Start virtualswitch service
4. Create switch group and switch definition
5. Create node with known MAC address
6. Create connection profile
7. Plug device via virtualswitch API with MAB auth
8. Verify RADIUS Accept in audit log
9. Verify device AUTHORIZED via virtualswitch API

### Printer + Fingerbank Test
10. Create printer role with VLAN 200
11. Create VLAN filter for auto-assigning printer role
12. Clear Fingerbank cache
13. Create printer node
14. Plug printer device (hp-printer profile)
15. Verify printer authentication and VLAN assignment

## Teardown

1. Unplug all devices from virtualswitch
2. Delete nodes, roles, filters, switch configuration
3. Stop virtualswitch service

## VirtualSwitch Configuration

The virtualswitch is configured with:
- 5 ethernet interfaces
- Cisco switch type simulation
- RADIUS pointing to PF registration interface
- VLANs: 2 (default), 100 (headless_device), 200 (printer)

## Differences from wired_mac_auth

| Aspect | wired_mac_auth | wired_mac_auth_virtualswitch |
|--------|----------------|------------------------------|
| VMs required | PF + switch01 + node01 + wireless01 | PF + virtualswitch01 |
| Switch type | Cumulus VX (NCLU API) | Cisco 15.5 (simulated) |
| Device simulation | Real node01 VM | VirtualSwitch API |
| Switch API | Cumulus NCLU REST API | VirtualSwitch REST API |
| Internet check | From node01 | From virtualswitch01 |
| Fingerbank test | N/A | Printer profile with DHCP fingerprint |
