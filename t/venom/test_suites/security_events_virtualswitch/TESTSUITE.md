# security_events_virtualswitch

Test security event triggers and enforcement using VirtualSwitch running in namespace mode on the PF VM itself.

## Overview

This test suite combines five security event scenarios into a single suite, each testing a different trigger mechanism:

1. **Manual** - Administrator manually applies a security event via API
2. **Detect MAC** - Automatic isolation triggered by MAC address pattern
3. **Detect Fingerbank** - Automatic autoreg triggered by Fingerbank device classification
4. **Delayed** - MAC trigger with delay_by period before enforcement
5. **Accounting** - Bandwidth threshold trigger with grace period

## File Numbering Convention

Test files use 3-digit prefixes with phase ranges:

### Test Files

| Range | Phase | Description |
|-------|-------|-------------|
| 000-014 | Phase 1: Manual | Apply event via API, verify isolation, close, verify restored |
| 020-038 | Phase 2: Detect MAC | Auto MAC trigger, isolation, close, delete trigger, verify normal |
| 050-068 | Phase 3: Detect Fingerbank | Fingerbank trigger, autoreg with guest role, verify VLAN |
| 080-102 | Phase 4: Delayed | Delayed MAC trigger, wait for delay, verify isolation, close |
| 110-138 | Phase 5: Accounting | Bandwidth trigger with grace period, verify retrigger |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 000-008 | Unplug Devices | Unplug all 5 test devices |
| 010-018 | Close Events | Close remaining security events for all MACs |
| 020-028 | Delete Nodes | Delete all 5 test nodes |
| 030-034 | Delete Security Events | Delete security event configurations |
| 040-048 | Delete Profiles | Delete all 5 connection profiles |
| 050 | Fingerbank Cleanup | Delete VLAN 99 routed network |
| 060-064 | Accounting Cleanup | Disable bandwidth accounting, restart pfacct, restore virtualswitch interval |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create roles, switch group, switch, configure registration interface with RADIUS listener, and restart services

## Phase Details

### Phase 1: Manual Security Event (000-014)
- Uses default security event 1300000 (Generic)
- Applies event via `apply_security_event` API
- Verifies device moves to isolation VLAN (6)
- Closes event and verifies device returns to normal VLAN (4)

### Phase 2: Detect MAC (020-038)
- Creates custom security event 9000002 with MAC trigger
- Device is automatically isolated on plug (MAC pattern match)
- After closing event, deletes the security event config
- Re-plugs device to verify normal VLAN without trigger

### Phase 3: Detect Fingerbank (050-068)
- Creates custom security event 9000004 with Fingerbank device trigger
- Uses `autoreg` + `role` actions to auto-register with guest role
- Creates VLAN 99 routed network for Fingerbank DHCP
- Verifies device gets guest VLAN after Fingerbank classification

### Phase 4: Delayed Security Event (080-102)
- Creates custom security event 9000003 with MAC trigger and 45s delay
- Verifies event status is `delayed` initially
- Device stays on normal VLAN during delay period
- After delay expiry + maintenance run, event transitions to `open`
- Verifies device moves to isolation VLAN

### Phase 5: Accounting Security Event (110-138)
- Enables bandwidth accounting and reconfigures virtualswitch interval
- Creates security event 9000001 with TOT500KBD trigger and grace period
- Waits for bandwidth to exceed 500KB threshold
- Verifies event triggered, closes it, verifies grace prevents retrigger
- After grace expiry, verifies event re-triggers

## VirtualSwitch Configuration

All phases use the same virtualswitch configuration:
- Wired ethernet interfaces
- Cisco switch type simulation
- RADIUS pointing to PF (10.255.255.1:1812)
- VLANs: guest=1, registration=2, headless_device=4, isolation=6
