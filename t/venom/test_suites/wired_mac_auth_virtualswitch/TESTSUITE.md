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
|  |  IP: 10.255.255.1/30          |<-->|  IP: 10.255.255.2/30         | |
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

## File Numbering Convention

Test files are numbered by phase to keep related steps grouped together:

### Test Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | PacketFence Infrastructure | Maintenance tasks |
| 1x | PacketFence Entities | Create nodes, profiles |
| 2x | Test 1: Headless Device | Execute MAB test and verify results |
| 3x | Test 2: Printer Setup | Enable VLAN filter, node |
| 4x | Test 2: Printer Execute | Execute printer test and verify results |
| 5x | Logging | Collect logs and artifacts |

### Teardown Files

Teardown runs in reverse order, cleaning up test artifacts first:

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Devices | Unplug test devices from virtualswitch |
| 1x | Delete Nodes | Delete test nodes |
| 2x | Delete Entities | Delete connection profile |
| 4x | Infrastructure Cleanup | Delete network, disable tasks |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create roles (headless_device, printer, windows, ios, android), switch group, switch, configure registration interface with RADIUS+DHCP listeners, create routed networks (VLANs 1-6), and restart services

## Network Setup

The test creates a veth pair connecting PacketFence to the virtualswitch:
- **vswitch-host**: Host side, configured as PF registration interface (10.255.255.1/30)
- **vswitch-ns**: Used by virtualswitch for RADIUS communication (10.255.255.2/30)

## Test Flow

### 0x - PacketFence Infrastructure
1. Enable node cleanup task
2. Enable DNS recording (`record_dns_in_sql`) and restart pfcron/pfdns — applies to both wired and wireless suites; disabled in the wireless teardown
3. Restart pfcron service

### 1x - PacketFence Entities
3. Create node with known MAC address
4. Create connection profile

### 2x - Test 1: Headless Device MAB
5. Plug device via virtualswitch API with MAB auth
6. Verify RADIUS Accept in audit log
7. Verify device AUTHORIZED via virtualswitch API
8. Check DNS audit log for device queries

### 3x - Test 2: Printer Setup
9. Enable printer VLAN filter (created disabled in global_config_virtualswitch)
10. Clear Fingerbank cache
11. Create printer node

### 4x - Test 2: Printer Execute & Verify
12. Plug printer device (hp-printer profile)
13. Verify printer RADIUS authentication
14. Trigger Fingerbank refresh via API
15. Verify Fingerbank detection
16. Verify VLAN assignment
17. Verify printer status via virtualswitch API

### 5x - Logging
18. Collect virtualswitch logs

Note: Roles (headless_device and printer) are created in `global_config_virtualswitch`.

## Teardown

### 0x - Unplug Devices
1. Unplug headless device
2. Unplug printer device
3. Unplug all interfaces (cleanup)

### 1x - Delete Nodes and Filters
Node unregistration is handled by the node cleanup cron task, so teardown only deletes:
4. Delete headless device node
5. Delete printer node
6. Disable printer VLAN filter

### 2x - Delete Entities
7. Delete connection profile

### 4x - Infrastructure Cleanup
8. Disable node cleanup task
9. Restart pfcron service

Note: Registration interface, routed networks, and roles/VLAN filter deletion are handled in `global_config_virtualswitch` (the VLAN filter is disabled here first).

## VirtualSwitch Configuration

The virtualswitch is configured with:
- 6 ethernet interfaces
- Cisco switch type simulation
- RADIUS pointing to PF (10.255.255.1:1812)
- Network mapping: 10.0.0.0 (VLAN X → 10.0.X.0/24)
- VLANs: guest=1, registration/printer=2, windows=3, headless_device/user/ios=4, android=5, isolation=6

## Differences from wired_mac_auth

| Aspect | wired_mac_auth | wired_mac_auth_virtualswitch |
|--------|----------------|------------------------------|
| VMs required | PF + switch01 + node01 + wireless01 | PF only |
| Switch type | Cumulus VX (NCLU API) | Cisco 15.5 (simulated) |
| Device simulation | Real node01 VM | VirtualSwitch API |
| Switch API | Cumulus NCLU REST API | VirtualSwitch REST API |
| Fingerbank test | N/A | Printer profile with DHCP fingerprint |
