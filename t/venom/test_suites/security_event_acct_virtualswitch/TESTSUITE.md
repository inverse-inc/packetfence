# security_event_acct_virtualswitch

Test bandwidth-based security event triggering with grace period using VirtualSwitch.

## Overview

This test suite verifies that PacketFence triggers a security event when a device exceeds
a bandwidth threshold, and that the grace period mechanism works correctly: preventing
re-trigger during the grace window and allowing re-trigger after grace expiry.

## File Numbering Convention

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Setup | Enable accounting, restart pfacct, configure virtualswitch interval, security event, connection profile, node |
| 1x | Test: Trigger | Plug device, verify auth, wait for bandwidth threshold |
| 1x-2x | Verify Trigger | Run acct maintenance, check security event triggered |
| 2x | Test: Grace Period | Close event, verify grace prevents retrigger |
| 2x-3x | Test: Re-trigger | Wait for grace expiry, run maintenance, verify retrigger |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Devices | Safety unplug device |
| 0x | Close Events | Close remaining security events |
| 0x | Delete Entities | Delete node, security event, connection profile |
| 1x | Restore Config | Disable bandwidth accounting, restart pfacct, restore virtualswitch interval |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, and restart services

## Test Flow

### 0x - Setup
1. Enable bandwidth accounting in RADIUS config
2. Restart pfacct service
3. Reconfigure virtualswitch with shorter accounting interval
4. Create security event with bandwidth trigger and grace period
5. Create connection profile
6. Create test node

### 1x - Test: Authentication & Bandwidth Trigger
7. Plug device via MAB
8. Verify device authenticated
9. Wait for bandwidth to exceed threshold
10. Run acct_maintenance pfcron task
11. Verify security event triggered (open status) and close it

### 2x - Test: Grace Period
12. Run acct_maintenance, verify grace period prevents re-trigger

### 2x-3x - Test: Re-trigger After Grace Expiry
13. Wait for grace period to expire
14. Run acct_maintenance again
15. Verify security event re-triggered

## Teardown

### 0x - Cleanup
1. Safety unplug device
2. Close any remaining security events
3. Delete test node
4. Delete security event configuration
5. Delete connection profile

### 1x - Restore Config
6. Disable bandwidth accounting
7. Restart pfacct
8. Restore virtualswitch default accounting interval
