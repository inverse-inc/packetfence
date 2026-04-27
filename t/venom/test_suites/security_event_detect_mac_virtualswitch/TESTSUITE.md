# security_event_detect_mac_virtualswitch

Test automatic security event triggering via MAC address detection using VirtualSwitch.

## Overview

A security event fires based on a MAC address pattern match during RADIUS authentication. A custom security event is created with a `MAC` trigger matching the test device's MAC address. The connection profile has `autoregister: enabled` so the node is created via `find_or_create` during RADIUS auth, which fires `node_discovered` and evaluates the MAC trigger. The device is placed in the isolation VLAN. After closing the event, removing the trigger configuration, updating the node role to `headless_device`, and re-connecting, the device should be assigned its normal VLAN (4).

## File Numbering Convention

| Range | Phase | Description |
|-------|-------|-------------|
| 00-02 | Setup | Create security event with MAC trigger, connection profile with autoregister |
| 06-08 | Test: Auto-Isolation | Plug device via MAB, MAC trigger fires automatically |
| 10-15 | Test: Close & Remove | Close security event, unplug, delete security event config, update node role |
| 16-18 | Test: Re-connect | Re-plug device without trigger, verify normal VLAN |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 00-06 | Cleanup | Unplug device, close events, delete node/connection profile |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, and restart services

## Test Flow

### 00-02 - Setup
1. Create security event with MAC trigger (`^00:0c:29:aa:bb:09`)
1. Clean RADIUS audit log
1. Create connection profile (Ethernet-NoEAP filter, autoregister enabled)

### 06-08 - Test: Automatic Isolation
1. Plug device via MAB on virtualswitch (autoregister creates node, `node_discovered` fires)
1. MAC trigger evaluates and fires
1. Verify device placed in isolation VLAN (6)

### 10-15 - Test: Close Event & Remove Trigger
1. Search for open security event, close it via API
1. Unplug device
1. Delete security event configuration (removes MAC trigger)
1. Update node role to headless_device (VLAN 4)

### 16-18 - Test: Re-connect Without Trigger
1. Re-plug device via MAB
1. Verify device authenticated on normal VLAN (4)

## Teardown

### 00-06 - Cleanup
1. Safety unplug device
1. Close any remaining security events (bulk close)
1. Delete test node
1. Delete connection profile
