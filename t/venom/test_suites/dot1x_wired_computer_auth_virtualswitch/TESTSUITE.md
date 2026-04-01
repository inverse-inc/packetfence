# dot1x_wired_computer_auth_virtualswitch

Test 802.1X wired computer authentication using VirtualSwitch.

## Overview

This test suite verifies that a computer device can authenticate via 802.1X (EAP-PEAP)
through the virtualswitch and receive proper VLAN assignment and node registration.

## File Numbering Convention

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Setup | Connection profile, computer node, local user |
| 1x | Test & Verify | Plug device, verify auth, VLAN, node status |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Devices | Unplug 802.1X device |
| 1x | Delete Nodes/Users | Delete computer node, delete local user |
| 2x | Delete Entities | Delete connection profile |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, enable local auth with NTLM hashing, and restart services

## Test Flow

### 0x - Setup
1. Create connection profile for 802.1X authentication
2. Create computer node with known MAC address
3. Create local test user with password

### 1x - Test: 802.1X Computer Authentication
4. Plug device via virtualswitch API with EAP-PEAP authentication
5. Verify RADIUS Accept in audit log
6. Verify VLAN assignment via virtualswitch API
7. Verify node status is registered

## Teardown

### 0x - Unplug Devices
1. Unplug 802.1X device

### 1x - Delete Nodes/Users
2. Delete computer node
3. Delete local test user

### 2x - Delete Entities
4. Delete connection profile
