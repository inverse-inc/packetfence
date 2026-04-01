# pfacct_bandwidth_virtualswitch

Test pfacct bandwidth accounting using VirtualSwitch.

## Overview

This test suite verifies the full bandwidth accounting pipeline: enabling accounting,
plugging a device, verifying RADIUS accounting data flows into the
bandwidth_accounting table, and confirming that
unplugging triggers an Accounting Stop with node unregistration (unreg_on_acct_stop).

## File Numbering Convention

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Setup | Enable accounting, restart pfacct, configure virtualswitch interval, connection profile, node |
| 1x | Test: Authenticated | Plug device, verify RADIUS auth, check device status |
| 1x-2x | Verify Accounting | Wait for data, check bandwidth_accounting |
| 2x | Test: Disconnect | Unplug device, verify acct stop, node unregistered |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Devices | Safety unplug device |
| 0x | Delete Nodes | Delete test node |
| 0x | Delete Entities | Delete connection profile |
| 0x | Restore Config | Disable bandwidth accounting, restart pfacct, restore virtualswitch interval |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, and restart services

## Test Flow

### 0x - Setup
1. Enable bandwidth accounting in RADIUS config
2. Restart pfacct service
3. Reconfigure virtualswitch with shorter accounting interval
4. Create connection profile (with unreg_on_acct_stop enabled)
5. Create test node

### 1x - Test: Authentication & Accounting
6. Plug device via MAB
7. Verify RADIUS Accept in audit log
8. Verify device authenticated via virtualswitch API
9. Verify node is online after accounting Start
10. Wait for accounting data (Start + interim-update)
11. Verify bandwidth_accounting table has in/out bytes

### 2x - Test: Disconnect & Unregistration
12. Unplug device to trigger Accounting Stop
13. Verify node is offline after accounting Stop
14. Verify node becomes unregistered (unreg_on_acct_stop)

## Teardown

### 0x - Unplug & Cleanup
1. Safety unplug device
2. Delete test node
3. Delete connection profile
4. Disable bandwidth accounting
5. Restart pfacct
6. Restore virtualswitch default accounting interval
