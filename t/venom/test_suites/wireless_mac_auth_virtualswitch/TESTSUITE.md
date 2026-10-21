# wireless_mac_auth_virtualswitch

Test Wireless MAC Authentication using VirtualSwitch running in namespace mode on the PF VM itself.

## Overview

This test suite uses virtualswitch running locally on the PacketFence VM to simulate
a wireless access point for MAC authentication testing. Unlike the `wireless_mac_auth` test suite
which requires separate VMs (wireless01 with hostapd/wpa_supplicant), this suite only requires
a single PF VM.

The virtualswitch interface 7 is configured as `wifi` type, which causes it to send
`NAS-Port-Type = Wireless-802.11` (value 19) in RADIUS requests, resulting in a
`Wireless-802.11-NoEAP` connection type in PacketFence.

## Architecture

```
+----------------------------------------------------------------------+
|                              PF VM (single VM)                        |
|                                                                      |
|  +-----------------------------+    +------------------------------+ |
|  |  PacketFence                |    |  VirtualSwitch               | |
|  |                             |    |                              | |
|  |  Admin API: :1443           |    |  REST API: :8080             | |
|  |  RADIUS: :1812              |    |  Interface 7: wifi (wl6)     | |
|  |                             |    |  NAS-Port-Type: 19           | |
|  |  vswitch-host interface     |    |  Called-Station-Id:          | |
|  |  (registration type)        |    |    <switch_mac>:<ssid>       | |
|  |  IP: 10.255.255.1/30        |<-->|  IP: 10.255.255.2/30        | |
|  |  DHCP enabled               |veth|                              | |
|  |                             |pair|                              | |
|  +-----------------------------+    +------------------------------+ |
+----------------------------------------------------------------------+
```

## Key Benefits

- **Single VM**: Only requires one PF VM (no wireless01 with hostapd/wpa_supplicant)
- **Self-contained**: VirtualSwitch simulates wireless via `wifi` interface type
- **Faster CI**: Reduced VM provisioning time
- **Simpler setup**: No external AP/client coordination

## File Numbering Convention

Test files are numbered by phase to keep related steps grouped together:

### Test Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | PacketFence Infrastructure | Services, node cleanup task |
| 1x | PacketFence Entities | Create node, connection profile |
| 2x | Test: Wireless MAB | Execute wireless MAB test and verify results |
| 5x | Logging | Collect logs and artifacts |

### Teardown Files

Teardown runs in reverse order, cleaning up test artifacts first:

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Devices | Unplug test device from virtualswitch |
| 1x | Delete Nodes | Delete test node |
| 2x | Delete Entities | Delete connection profile |
| 4x | Infrastructure Cleanup | Disable node cleanup task |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure (with interface 7 as wifi), start virtualswitch in namespace, create roles, switch group, switch, configure registration interface with RADIUS+DHCP listeners, create routed networks, and restart services

## Test Flow

### 0x - PacketFence Infrastructure
1. Restart services
2. Enable node cleanup task
3. Restart pfcron service

### 1x - PacketFence Entities
4. Create node with known MAC address and headless_device role
5. Create connection profile filtering on `Wireless-802.11-NoEAP`

### 2x - Test: Wireless Device MAB
6. Plug device via virtualswitch API on interface 7 (wifi) with MAB auth
7. Verify RADIUS Accept in audit log with `Wireless-802.11-NoEAP` connection type
8. Verify device AUTHORIZED via virtualswitch API
9. Check DNS audit log for device queries

### 5x - Logging
10. Collect virtualswitch logs

Note: Roles (headless_device) are created in `global_config_virtualswitch`.

## Teardown

### 0x - Unplug Devices
1. Unplug wireless device (interface 7)
2. Unplug all interfaces (cleanup)

### 1x - Delete Nodes
3. Delete wireless device node

### 2x - Delete Entities
4. Delete connection profile

### 4x - Infrastructure Cleanup
5. Disable node cleanup task
6. Disable DNS recording (`record_dns_in_sql`) and restart pfcron/pfdns — this is the last suite to run in the `mac_auth_virtualswitch` scenario, so DNS recording (enabled in `wired_mac_auth_virtualswitch/04_enable_dns_recording_restart_services.yml`) is turned off here

Note: Registration interface, routed networks, and roles deletion are handled in `global_config_virtualswitch`.

## VirtualSwitch Configuration

The virtualswitch is configured with:
- 7 interfaces (1-6 ethernet, 7 wifi)
- Cisco switch type simulation
- RADIUS pointing to PF (10.255.255.1:1812)
- Network mapping: 10.0.0.0 (VLAN X -> 10.0.X.0/24)
- VLANs: guest=1, registration/printer=2, windows=3, headless_device/user/ios=4, android=5, isolation=6

## Differences from wireless_mac_auth

| Aspect | wireless_mac_auth | wireless_mac_auth_virtualswitch |
|--------|-------------------|--------------------------------|
| VMs required | PF + wireless01 | PF only |
| AP type | hostapd on wireless01 | VirtualSwitch wifi interface |
| Device auth trigger | wpa_supplicant via SSH | VirtualSwitch plug API |
| Connection type | Wireless-802.11-NoEAP | Wireless-802.11-NoEAP |
| NAS-Port-Type | Real wireless (19) | Simulated wireless (19) |
| Called-Station-Id | Real AP MAC:SSID | VirtualSwitch switch_mac:ssid |

## Differences from wired_mac_auth_virtualswitch

| Aspect | wired_mac_auth_virtualswitch | wireless_mac_auth_virtualswitch |
|--------|------------------------------|--------------------------------|
| Interface type | ethernet (interface 1) | wifi (interface 7) |
| Connection type filter | Ethernet-NoEAP | Wireless-802.11-NoEAP |
| NAS-Port-Type | 15 (Ethernet) | 19 (Wireless-802.11) |
| Called-Station-Id | switch_mac | switch_mac:ssid |
| Printer/Fingerbank test | Yes | No |
