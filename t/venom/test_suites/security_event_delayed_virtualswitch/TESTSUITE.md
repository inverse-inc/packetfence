# security_event_delayed_virtualswitch

Test delayed security event enforcement using VirtualSwitch. When a security event is configured with `delay_by`, it should not be enforced immediately. Instead, it transitions to `open` (and isolates the device) only after the delay expires and `security_event_maintenance` runs.

## Overview

This test suite verifies that PacketFence correctly handles the `delay_by` security event configuration. A custom security event is created with a MAC trigger and a 45-second delay. When the device connects via MAB, the trigger fires automatically but the event is created with status `delayed` — the device stays on its normal VLAN. After waiting for the delay to expire, `security_event_maintenance` is run via pfcron, which transitions the event to `open` and executes the `reevaluate_access` action, moving the device to the isolation VLAN.

## File Numbering Convention

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Setup | Create security event with MAC trigger and delay_by, connection profile, node |
| 0x | Test: Authentication | Plug device via MAB, verify authenticated on normal VLAN (4) |
| 1x | Verify: Delayed | Check security event has status `delayed`, device still on normal VLAN |
| 1x | Test: Wait & Maintain | Wait for delay expiry, run security_event_maintenance |
| 1x | Verify: Enforced | Check event transitioned to `open`, device on isolation VLAN (6) |
| 2x | Test: Close Event | Close security event, verify device returns to normal VLAN (4) |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Device | Safety unplug device |
| 0x | Close Events | Close any remaining security events |
| 0x | Delete Entities | Delete node, security event config, connection profile |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, and restart services

## Test Flow

### 0x - Setup
1. Create security event (id 9000003) with MAC trigger (`^00:0c:29:aa:bb:0a`) and `delay_by: 45s`
2. Create connection profile (Ethernet-NoEAP filter)
3. Create test node with headless_device role (VLAN 4)

### 0x - Test: Authentication
4. Plug device via MAB on virtualswitch
5. Verify device authenticated on normal VLAN (4) — MAC trigger fires but event is delayed

### 1x - Verify: Delayed Status
6. Search security events, verify status is `delayed` (not `open`)
7. Verify device still on normal VLAN (4) — delayed event does not isolate

### 1x - Test: Wait for Delay & Run Maintenance
8. Wait 60 seconds (45s delay + buffer)
9. Run `security_event_maintenance` pfcron task to process expired delayed events

### 1x - Verify: Enforcement
10. Search security events, verify status transitioned to `open`
11. Verify device moved to isolation VLAN (6) via CoA

### 2x - Test: Close Event & Restore
12. Close the security event, verify device returns to normal VLAN (4)

## Teardown

### 0x - Cleanup
1. Safety unplug device
2. Close any remaining security events (bulk close)
3. Delete test node
4. Delete security event configuration
5. Delete connection profile
