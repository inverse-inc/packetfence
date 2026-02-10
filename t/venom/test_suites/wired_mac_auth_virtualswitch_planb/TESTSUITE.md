# wired_mac_auth_virtualswitch_planb Test Suite

This test suite validates MAC authentication using VirtualSwitch running on a **separate VM** (virtualswitch01), connected to the PF VM via the management network.

## Architecture (Plan B - Separate VM)

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│         PF VM               │     │   virtualswitch01 VM        │
│                             │     │                             │
│  ┌─────────────────────┐   │     │   ┌─────────────────────┐   │
│  │  PacketFence        │   │     │   │  VirtualSwitch      │   │
│  │  - RADIUS:1812      │◄──┼─────┼───│  - API: :8080       │   │
│  │  - Admin:1443       │   │     │   │  - simulated devices│   │
│  └─────────────────────┘   │     │   └─────────────────────┘   │
│                             │     │                             │
│  Management Network         │     │   Management Network        │
│  eth0: 172.18.X.10         │     │   eth0: 172.18.X.103        │
└─────────────────────────────┘     └─────────────────────────────┘
```

## Key Differences from Plan A (Namespace)

| Aspect | Plan A (Namespace) | Plan B (Separate VM) |
|--------|-------------------|----------------------|
| VMs required | 1 (PF only) | 2 (PF + virtualswitch01) |
| VirtualSwitch location | Network namespace on PF | Separate VM |
| Network setup | veth pair | Standard VM networking |
| RADIUS path | localhost via veth | VM to VM via mgmt network |
| Internet test | Not possible | Possible |

## Prerequisites

- PF VM provisioned with registration interface configured
- virtualswitch01 VM provisioned with virtualswitch package installed

## Test Files

| File | Description |
|------|-------------|
| `00_check_virtualswitch_api.yml` | Verify virtualswitch API is accessible |
| `01_configure_virtualswitch.yml` | Configure virtualswitch via API (RADIUS settings) |
| `02_enable_node_cleanup_task.yml` | Enable node cleanup maintenance task |
| `04_restart_pfcron_service.yml` | Restart pfcron |
| `06_create_switch_group.yml` | Create switch group for virtualswitch |
| `08_create_switch.yml` | Create switch definition (Cisco 15.5) |
| `10_create_role.yml` | Create headless_device role |
| `12_create_node.yml` | Create node with specified MAC |
| `14_create_connection_profile.yml` | Create wired MAC auth connection profile |
| `16_plug_device_mab.yml` | Plug device via virtualswitch REST API with MAB |
| `18_check_radius_audit_log.yml` | Verify RADIUS Accept in audit log |
| `20_check_virtualswitch_device_status.yml` | Verify device AUTHORIZED via virtualswitch API |
| `22_create_printer_role.yml` | Create printer role with dedicated VLAN |
| `24_create_vlan_filter_printer.yml` | Create VLAN filter for printer auto-assignment |
| `26_clear_fingerbank_cache.yml` | Clear Fingerbank cache |
| `28_create_printer_node.yml` | Create printer node with known MAC |
| `30_plug_printer_mab.yml` | Plug printer device via virtualswitch API |
| `32_check_printer_radius_audit_log.yml` | Verify printer RADIUS Accept |
| `34_check_printer_fingerbank_detection.yml` | Verify Fingerbank detected Printer device class |
| `36_check_printer_vlan_assignment.yml` | Verify printer was assigned to printer role |
| `38_check_printer_virtualswitch_status.yml` | Verify printer AUTHORIZED |
| `40_collect_virtualswitch_logs.yml` | Collect logs for CI artifacts |

## Teardown Files

| File | Description |
|------|-------------|
| `00_unplug_device.yml` | Unplug device from virtualswitch |
| `02_unplug_printer.yml` | Unplug printer from virtualswitch |
| `04_unreg_node.yml` | Unregister device node |
| `06_unreg_printer_node.yml` | Unregister printer node |
| `08_delete_node.yml` | Delete device node |
| `10_delete_printer_node.yml` | Delete printer node |
| `12_delete_connection_profile.yml` | Delete connection profile |
| `14_delete_vlan_filter_printer.yml` | Delete printer VLAN filter |
| `16_delete_switch.yml` | Delete switch |
| `18_delete_switch_group.yml` | Delete switch group |
| `19_delete_printer_role.yml` | Delete printer role (after switch group) |
| `19b_delete_headless_device_role.yml` | Delete headless_device role (after switch group) |
| `20_unplug_all_interfaces.yml` | Cleanup all virtualswitch interfaces |
| `22_disable_node_cleanup_task.yml` | Disable cleanup task |
| `24_restart_pfcron_service.yml` | Restart pfcron |

## Variables Used

Variables are defined in `t/venom/vars/all.yml` under the `wired_mac_auth_virtualswitch_planb` section.

Key variables:
- `virtualswitch_planb.api.url` - API URL on virtualswitch01 VM
- `virtualswitch_planb.radius.ip` - PF registration interface IP
- `virtualswitch_planb_switch.id` - Switch identifier (virtualswitch01 mgmt IP)
