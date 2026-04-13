# security_event_manual_virtualswitch

Test manually triggering a security event on a connected device via the Web Admin API, verifying isolation VLAN assignment, then closing the event and verifying the device returns to its normal VLAN.

## Overview

This test suite verifies that an administrator can manually apply a security event (default event 1300000 "Generic") to a connected device via the PacketFence API. When the event is applied, the device should be moved to the isolation VLAN via CoA (Change of Authorization). When the event is closed, the device should return to its normal VLAN.

## File Numbering Convention

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Setup | Create connection profile, create node with headless_device role |
| 0x | Test: Authentication | Plug device via MAB, verify authenticated on normal VLAN (4) |
| 0x | Test: Apply Event | Apply security event 1300000 via API |
| 1x | Verify: Isolation | Check device moved to isolation VLAN (6) |
| 1x | Test: Close Event | Search for open event, close it via API |
| 1x | Verify: Restored | Check device returned to normal VLAN (4) |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Device | Safety unplug device |
| 0x | Close Events | Close any remaining security events |
| 0x | Delete Entities | Delete node, connection profile |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, and restart services

### Default security events

This test uses the default PacketFence security event **1300000 (Generic)** which must be enabled with:
- `vlan: isolation`
- `actions: reevaluate_access`

No custom security event configuration is created by this test.

## Test Flow

### 0x - Setup
1. Create connection profile (Ethernet-NoEAP filter)
2. Create test node with headless_device role (VLAN 4)

### 0x - Test: Authentication
3. Plug device via MAB on virtualswitch
4. Verify device authenticated on normal VLAN (4)

### 0x - Test: Apply Security Event
5. Apply security event 1300000 (Generic) via `PUT /api/v1/node/{mac}/apply_security_event`

### 1x - Verify: Isolation
6. Verify device moved to isolation VLAN (6) via CoA

### 1x - Test: Close Security Event
7. Search for open security event on the node
8. Close it via `POST /api/v1/node/{mac}/close_security_event`

### 1x - Verify: Restored
9. Verify device returned to normal VLAN (4) via CoA

## Teardown

### 0x - Cleanup
1. Safety unplug device
2. Close any remaining security events (bulk close)
3. Delete test node
4. Delete connection profile
