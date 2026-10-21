# device_profiling_virtualswitch

Test Fingerbank device profiling using VirtualSwitch to simulate different device types.

## Overview

This test suite verifies that PacketFence correctly identifies device types via Fingerbank
when devices connect through the virtualswitch. Three device profiles are tested:
Windows 11, iOS (iPhone), and Android (Samsung).

Each device follows the same pattern: create node, plug via MAB, trigger Fingerbank refresh,
verify Fingerbank detection.

## File Numbering Convention

Test files are numbered by device group:

### Test Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Setup | Connection profile, clear Fingerbank cache |
| 1x | Test 1: Windows | Create node, plug, refresh fingerbank, verify detection |
| 2x | Test 2: iOS | Create node, plug, refresh fingerbank, verify detection |
| 3x | Test 3: Android | Create node, plug, refresh fingerbank, verify detection |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 0x | Unplug Devices | Unplug all test devices |
| 1x | Delete Nodes | Delete all test nodes |
| 2x | Delete Entities | Delete connection profile |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, and restart services

## Test Flow

### 0x - Setup
1. Create connection profile for wired MAB
2. Clear Fingerbank cache

### 1x - Test 1: Windows
3. Create Windows node
4. Plug Windows device (windows11 profile)
5. Trigger Fingerbank refresh via API
6. Verify Fingerbank detects device_class containing "Windows"

### 2x - Test 2: iOS
7. Create iOS node
8. Plug iOS device (iphone profile)
9. Trigger Fingerbank refresh via API
10. Verify Fingerbank detects device_class containing "Apple"

### 3x - Test 3: Android
11. Create Android node
12. Plug Android device (android_samsung profile)
13. Trigger Fingerbank refresh via API
14. Verify Fingerbank detects device_class containing "Android"

## Teardown

### 0x - Unplug Devices
1. Unplug Windows device
2. Unplug iOS device
3. Unplug Android device

### 1x - Delete Nodes
4. Delete Windows node
5. Delete iOS node
6. Delete Android node

### 2x - Delete Entities
7. Delete connection profile
