# mac_auth_virtualswitch

Test Wired and Wireless MAC Authentication using VirtualSwitch running in namespace mode on the PF VM itself.

## Overview

This test suite uses virtualswitch running locally on the PacketFence VM to simulate
both a network switch (wired) and a wireless access point for MAC authentication testing.
It combines wired and wireless MAB tests into a single suite.

## Architecture

```
+----------------------------------------------------------------------+
|                              PF VM (single VM)                        |
|                                                                      |
|  +-----------------------------+    +------------------------------+ |
|  |  PacketFence                |    |  VirtualSwitch               | |
|  |                             |    |                              | |
|  |  Admin API: :1443           |    |  REST API: :8080             | |
|  |  RADIUS: :1812              |    |  Interfaces 1-6: ethernet    | |
|  |                             |    |  Interface 7: wifi (wl6)     | |
|  |  vswitch-host interface     |    |  NAS-Port-Type: 15 or 19    | |
|  |  (registration type)        |    |                              | |
|  |  IP: 10.255.255.1/30        |<-->|  IP: 10.255.255.2/30        | |
|  |  DHCP enabled               |veth|                              | |
|  |                             |pair|                              | |
|  +-----------------------------+    +------------------------------+ |
+----------------------------------------------------------------------+
```

## File Numbering Convention

Test files are numbered by phase to keep related steps grouped together:

### Test Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | PacketFence Infrastructure | Node cleanup task, RADIUS audit log, DNS recording |
| 1x | Wired Entities | Create wired node, wired connection profile |
| 2x | Test 1: Wired Headless Device | Execute wired MAB test and verify results |
| 3x | Test 2: Printer Setup | Enable VLAN filter, clear cache, create printer node |
| 4x | Test 2: Printer Execute | Execute printer test and verify results |
| 5x | Wireless Prep | Restart pfcron, clean RADIUS log, create wireless entities |
| 6x | Test 3: Wireless Device | Execute wireless MAB test and verify results |
| 7x | Logging | Collect logs and artifacts |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Devices | Unplug wired, printer, wireless devices, then all interfaces |
| 1x | Delete Nodes & Filters | Delete nodes, disable VLAN filter |
| 2x | Delete Entities | Delete wired and wireless connection profiles |
| 3x | Infrastructure Cleanup | Disable tasks, DNS recording, restart services |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create roles (headless_device, printer, windows, ios, android), switch group, switch, configure registration interface with RADIUS+DHCP listeners, create routed networks (VLANs 1-6), and restart services

## Test Flow

### 0x - PacketFence Infrastructure
1. `00` Enable node cleanup task
2. `02` Clean stale RADIUS audit log entries
3. `04` Enable DNS recording (`record_dns_in_sql`) and restart pfcron/pfdns

### 1x - Wired Entities
4. `10` Create wired node with known MAC address
5. `12` Create wired connection profile (Ethernet-NoEAP)

### 2x - Test 1: Wired Headless Device MAB
6. `20` Plug device via virtualswitch API with MAB auth (interface 1)
7. `22` Verify RADIUS Accept in audit log
8. `24` Verify device AUTHORIZED via virtualswitch API
9. `26` Check DNS audit log for device queries

### 3x - Test 2: Printer Setup
10. `30` Enable printer VLAN filter
11. `32` Clear Fingerbank cache
12. `34` Create printer node

### 4x - Test 2: Printer Execute & Verify
13. `40` Plug printer device (hp-printer profile, interface 2)
14. `42` Verify printer RADIUS authentication
15. `44` Trigger Fingerbank refresh via API
16. `46` Verify Fingerbank detection
17. `48` Verify VLAN assignment
18. `49` Verify printer status via virtualswitch API

### 5x - Wireless Prep
19. `50` Restart pfcron service
20. `52` Clean RADIUS audit log (fresh for wireless tests)
21. `54` Create wireless node with known MAC address
22. `56` Create wireless connection profile (Wireless-802.11-NoEAP)

### 6x - Test 3: Wireless Device MAB
23. `60` Plug device via virtualswitch API on interface 7 (wifi) with MAB auth
24. `62` Verify RADIUS Accept with `Wireless-802.11-NoEAP` connection type
25. `64` Verify device AUTHORIZED via virtualswitch API
26. `66` Check DNS audit log for device queries

### 7x - Logging
27. `70` Collect virtualswitch logs

## Teardown

### 0x - Unplug Devices
1. `00` Unplug wired headless device
2. `02` Unplug printer device
3. `04` Unplug wireless device
4. `06` Unplug all interfaces (cleanup, interfaces 1-7)

### 1x - Delete Nodes and Filters
5. `10` Delete wired headless device node
6. `12` Delete printer node
7. `14` Delete wireless device node
8. `16` Disable printer VLAN filter

### 2x - Delete Entities
9. `20` Delete wired connection profile
10. `22` Delete wireless connection profile

### 3x - Infrastructure Cleanup
11. `30` Disable node cleanup task
12. `32` Disable DNS recording and restart services

## VirtualSwitch Configuration

The virtualswitch is configured with:
- 7 interfaces (1-6 ethernet, 7 wifi)
- Cisco switch type simulation
- RADIUS pointing to PF (10.255.255.1:1812)
- Network mapping: 10.0.0.0 (VLAN X -> 10.0.X.0/24)
- VLANs: guest=1, registration/printer=2, windows=3, headless_device/user/ios=4, android=5, isolation=6

## Wired vs Wireless Differences

| Aspect | Wired (Tests 1-2) | Wireless (Test 3) |
|--------|-------------------|-------------------|
| Interface type | ethernet (interfaces 1-2) | wifi (interface 7) |
| Connection type | Ethernet-NoEAP | Wireless-802.11-NoEAP |
| NAS-Port-Type | 15 (Ethernet) | 19 (Wireless-802.11) |
| Called-Station-Id | switch_mac | switch_mac:ssid |
