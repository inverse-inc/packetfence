# wired_mac_auth_virtualswitch

Test MAC Authentication using VirtualSwitch running in namespace mode on the PF VM itself.

## Overview

This test suite uses virtualswitch running locally on the PacketFence VM to simulate
a network switch for MAC authentication testing. Unlike the `wired_mac_auth` test suite
which requires separate VMs (switch01, node01, wireless01), this suite only requires
a single PF VM.

## Architecture

```
+----------------------------------------------------------------------+
|                              PF VM (single VM)                        |
|                                                                      |
|  +-----------------------------+    +------------------------------+ |
|  |  PacketFence                |    |  VirtualSwitch               | |
|  |                             |    |                              | |
|  |  Admin API: :1443           |    |  REST API: :8080             | |
|  |  RADIUS: :1812              |    |  Simulated devices           | |
|  |                             |    |  RADIUS client               | |
|  |  vswitch-host interface     |    |                              | |
|  |  (registration type)        |    |  vswitch-ns interface        | |
|  |  IP: 10.99.99.1/24          |<-->|  IP: 10.99.99.254/24         | |
|  |  DHCP enabled               |veth|                              | |
|  |                             |pair|                              | |
|  +-----------------------------+    +------------------------------+ |
+----------------------------------------------------------------------+
```

## Key Benefits

- **Single VM**: Only requires one PF VM (no switch01, node01, wireless01)
- **Self-contained**: VirtualSwitch runs as a service on the PF VM
- **Faster CI**: Reduced VM provisioning time
- **Simpler setup**: No external switch/node coordination

## Requirements

### Global config steps
1. Create a role `headless_device`
2. Create a role `printer` (for Fingerbank tests)
3. Create switches and switch groups with role mapping

## Network Setup

The test creates a veth pair connecting PacketFence to the virtualswitch:
- **vswitch-host**: Host side, configured as PF registration interface (10.99.99.1/24)
- **vswitch-ns**: Used by virtualswitch for RADIUS communication (10.99.99.254/24)

## Test Flow

### Basic MAC Auth Test
1. Setup network (veth pair)
2. Install virtualswitch package
3. Configure virtualswitch with RADIUS pointing to PF
4. Start virtualswitch-namespace service
5. Configure PF interface and network
6. Create switch group and switch definition
7. Create node with known MAC address
8. Create connection profile
9. Plug device via virtualswitch API with MAB auth
10. Verify RADIUS Accept in audit log
11. Verify device AUTHORIZED via virtualswitch API

### Printer + Fingerbank Test
12. Create printer role with VLAN 200
13. Create VLAN filter for auto-assigning printer role
14. Clear Fingerbank cache
15. Create printer node
16. Plug printer device (hp-printer profile)
17. Verify printer authentication and VLAN assignment

## Teardown

1. Unplug all devices from virtualswitch
2. Delete nodes, roles, filters, switch configuration
3. Stop virtualswitch-namespace service
4. Remove network configuration (veth pair)

## VirtualSwitch Configuration

The virtualswitch is configured with:
- 5 ethernet interfaces
- Cisco switch type simulation
- RADIUS pointing to PF (10.99.99.1:1812)
- VLANs: 2 (default), 100 (headless_device), 200 (printer)

## Differences from wired_mac_auth

| Aspect | wired_mac_auth | wired_mac_auth_virtualswitch |
|--------|----------------|------------------------------|
| VMs required | PF + switch01 + node01 + wireless01 | PF only |
| Switch type | Cumulus VX (NCLU API) | Cisco 15.5 (simulated) |
| Device simulation | Real node01 VM | VirtualSwitch API |
| Switch API | Cumulus NCLU REST API | VirtualSwitch REST API |
| Fingerbank test | N/A | Printer profile with DHCP fingerprint |
