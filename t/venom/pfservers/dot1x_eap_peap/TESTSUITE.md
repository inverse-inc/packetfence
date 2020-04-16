# Test suite

## Requirements

### Global config
1. Create access duration
1. Create dot1x roles
1. Create switches and switch groups

## Test suite
1. Join domain
1. Configure REALM
1. Create AD sources
1. Create connection profile with auto-registration, AD sources and specific filter
1. Perform Checkup (common test suite)
1. Start wpa_supplicant *on* node01
1. Check RADIUS audit log for node01
1. Check node status for node01
1. Check VLAN assigned to node01 *on* switch01
1. Check Internet access *on* node01
1. Teardown
