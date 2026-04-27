# vlan_inheritance_virtualswitch

Test VLAN inheritance through roles using VirtualSwitch. Verifies that when a role has `inherit_vlan=enabled` and a `parent_id`, the VLAN is correctly resolved by walking up the parent chain in the switch group configuration.

## Overview

This test suite creates a 3-level role inheritance chain and verifies VLAN assignment through three phases:
1. Full inheritance with VLANs on Inheritance1 and Inheritance2
2. Remove Inheritance2's VLAN — inheritance walks up to Inheritance1
3. Disable inherit_vlan on Inheritance2 — inheritance chain breaks, no VLAN assigned (stays on native)

### Role Inheritance Chain

```
Inheritance1 (inherit_vlan=disabled)
  └── Inheritance2 (inherit_vlan=enabled, parent_id=Inheritance1)
        └── Inheritance3 (inherit_vlan=enabled, parent_id=Inheritance2)
```

### VLAN Resolution Logic (lib/pf/Switch.pm)

`getVlanByName(roleName)` resolves VLANs:
1. Check `{roleName}Vlan` in switch group config
2. If not found/empty and `inherit_vlan=enabled` → walk to `parent_id`
3. Recursively resolve until found or chain ends
4. If nothing found → no VLAN assigned (port stays on native VLAN)

## File Numbering Convention

### Test Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Setup | Create roles, configure switch group VLANs, connection profile, node |
| 1x-2x | Test Phase 1 | Full inheritance: Inheritance3→5, Inheritance2→5, Inheritance1→3 |
| 3x-5x | Test Phase 2 | Remove Inheritance2Vlan: all roles resolve to VLAN 3 |
| 6x-8x | Test Phase 3 | Disable inherit_vlan: Inheritance3→no VLAN, Inheritance2→no VLAN, Inheritance1→3 |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug & Delete | Unplug device, delete node, delete connection profile |
| 0x | Restore Config | Restore inherit_vlan on Inheritance2, remove VLANs from switch group |
| 1x | Apply & Delete | Configreload, delete roles (children first) |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface, create routed networks, and restart services

### Scenario

Runs as part of the `mac_auth_virtualswitch` scenario, after `mac_auth_virtualswitch`.

## Test Flow

### 0x - Setup
1. Create roles: Inheritance1 (inherit_vlan=disabled), Inheritance2 (inherit_vlan=enabled, parent=Inheritance1), Inheritance3 (inherit_vlan=enabled, parent=Inheritance2)
2. PATCH switch group: add Inheritance1Vlan=3, Inheritance2Vlan=5
3. Configreload hard + restart radiusd-auth
4. Create connection profile (Ethernet-NoEAP filter)
5. Create node with Inheritance3 role

### 1x-2x - Test Phase 1: Full Inheritance Chain (Inheritance2Vlan=5, Inheritance1Vlan=3)
6. Plug device (Inheritance3 role) → verify VLAN=5 (inherited from Inheritance2)
7. Unplug, change to Inheritance2 → verify VLAN=5 (direct mapping)
8. Unplug, change to Inheritance1 → verify VLAN=3 (direct mapping)

### 3x-5x - Test Phase 2: Remove Inheritance2Vlan
9. PATCH switch group: remove Inheritance2Vlan (set to empty)
10. Configreload hard + restart radiusd-auth
11. Change to Inheritance3, plug → verify VLAN=3 (walks: Inheritance3→Inheritance2→Inheritance1)
12. Unplug, change to Inheritance2 → verify VLAN=3 (inherits from Inheritance1)
13. Unplug, change to Inheritance1 → verify VLAN=3 (direct mapping)

### 6x-8x - Test Phase 3: Disable inherit_vlan on Inheritance2
14. PATCH role Inheritance2: inherit_vlan=disabled
15. Configreload hard + restart radiusd-auth
16. Change to Inheritance3, plug → verify VLAN=99 (chain breaks at Inheritance2, no VLAN assigned, stays on native)
17. Unplug, change to Inheritance2 → verify VLAN=99 (no VLAN, no inheritance, stays on native)
18. Unplug, change to Inheritance1 → verify VLAN=3 (direct mapping, unaffected)

## Teardown

1. Safety unplug device
2. Delete node
3. Delete connection profile
4. Restore Inheritance2 inherit_vlan=enabled (undo Phase 3)
5. Remove Inheritance1Vlan and Inheritance2Vlan from switch group (undo Phase 1+2)
6. Configreload hard (apply config changes)
7. Delete Inheritance3 (child first)
8. Configreload hard (refresh pfconfig cache so parent_id references are cleared)
9. Delete Inheritance2
10. Configreload hard
11. Delete Inheritance1

## VirtualSwitch Configuration

Uses the shared virtualswitch from `global_config_virtualswitch`:
- Interface 6 for device testing
- MAC: 00:0c:29:aa:bb:0b
- VLANs: 3 (Inheritance1), 5 (Inheritance2), 99 (native/no VLAN fallback)
