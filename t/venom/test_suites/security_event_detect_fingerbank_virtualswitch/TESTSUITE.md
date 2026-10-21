# security_event_detect_fingerbank_virtualswitch

Test automatic device autoregistration via a security event with a Fingerbank device trigger using VirtualSwitch.

## Overview

A security event with `autoreg` + `role` actions and a `device` trigger (Fingerbank device ID 1 = Windows) autoregisters a Windows device with the `guest` role when the trigger matches.

A routed network with DHCP is created for VLAN 99 (the virtualswitch default management VLAN) so that devices can complete a DHCP handshake and be fingerprinted by pfdhcplistener. The connection profile does NOT have autoregister enabled — autoregistration happens entirely through the security event.

After the device connects via MAB and Fingerbank classifies it as Windows, the security event trigger is explicitly evaluated via `pfcmd security_event trigger`. The `role` action sets `target_category` (guest), then the `autoreg` action registers the device and calls `reevaluate_access`. Since there is no `reevaluate_access` action in the config, the security event is force-closed after actions run.

The test verifies the device is registered with the `guest` role, then unplugs and re-plugs to confirm the device gets the guest VLAN (1).

## File Numbering Convention

| Range | Phase | Description |
|-------|-------|-------------|
| 00 | Setup | Create routed network for VLAN 99 (DHCP) |
| 02-04 | Setup | Create security event (autoreg + device trigger), connection profile (no autoregister) |
| 06-12 | Setup | Plug device, verify auth, refresh Fingerbank, verify classification |
| 14 | Trigger | Trigger security event evaluation via pfcmd |
| 16 | Verify | Check device is autoregistered with guest role |
| 18 | Verify | Unplug/re-plug, check device gets guest VLAN (1) |

### Teardown Files

| Range | Phase | Description |
|-------|-------|-------------|
| 00-10 | Cleanup | Unplug device, close events, delete node/security event/connection profile/routed network |

## Requirements

### Global config test suites

This test suite depends on:
- `global_config_virtualswitch`: Install, configure, start virtualswitch in namespace, create switch group, switch, configure registration interface with RADIUS listener, and restart services

## Test Flow

### 00-04 - Setup
1. Create routed network for VLAN 99 with DHCP
1. Create security event with `autoreg` + `role` actions, `target_category: guest`, device trigger (ID 1 = Windows), config reload
1. Create connection profile (Ethernet-NoEAP, no autoregister, sources null), config reload

### 06-12 - Plug Device and Verify Fingerbank Classification
1. Plug Windows device via MAB (lands on VLAN 99, gets DHCP, Fingerbank classifies)
1. Verify device is authenticated
1. Trigger Fingerbank refresh via API
1. Verify Fingerbank classified device as Windows (manufacturer = Microsoft)

### 14 - Trigger Security Event
1. Evaluate device trigger via `pfcmd security_event trigger` (opens event, actions execute: role → autoreg)

### 16 - Verify Autoregistration
1. Verify node status = `reg` and category = `guest` via API

### 18 - Verify VLAN Assignment
1. Unplug device, re-plug via MAB
1. Verify device gets guest VLAN (1)

## Teardown

### 00-10 - Cleanup
1. Safety unplug device
1. Close any remaining security events (bulk close)
1. Delete test node
1. Delete security event configuration
1. Delete connection profile
1. Delete VLAN 99 routed network
