# global_config_virtualswitch

Setup and teardown for virtualswitch and PacketFence switch configuration.

## Setup steps

### 0x - VirtualSwitch Infrastructure
1. Install virtualswitch package
2. Disable the standard virtualswitch service
3. Configure virtualswitch settings (network_mapping: 10.0.0.0, 7 interfaces: 1-6 ethernet, 7 wifi)
4. Start virtualswitch in a dedicated network namespace

### 2x - Roles and Filters
5. Create headless_device role
6. Create printer role
7. Create printer VLAN filter (disabled by default)
8. Create device profiling roles (windows, ios, android)

### 3x - PacketFence Switch Configuration
9. Create switch group (VLAN mapping: guest=1, registration=2, printer=2, windows=3, headless_device=4, user=4, ios=4, android=5, isolation=6)
10. Create switch

### 4x - PacketFence Interface and Network Configuration
11. Configure vswitchbr bridge as registration interface with RADIUS and DHCP listeners
12. Create routed networks for VLANs 1-6 (L3 DHCP via namespace)
13. Restart services (radiusd-auth, pfdhcp, pfdhcplistener)
14. Enable RADIUS local authentication and NTLM password hashing

## Teardown steps

### 0x - PacketFence Interface and Network Configuration
1. Deconfigure registration interface
2. Delete routed networks (VLANs 1-6)

### 0x - PacketFence Switch Configuration
3. Delete switch
4. Delete switch group

### 0x - Filters and Roles
5. Disable VLAN filter
6. Delete VLAN filter
7. Run configreload hard before deleting roles
8. Delete headless_device role
9. Delete printer role
10. Delete device profiling roles (windows, ios, android)

### 1x - VirtualSwitch Infrastructure
11. Stop and disable virtualswitch namespace service
12. Remove virtualswitch configuration
13. Disable RADIUS local authentication and restore bcrypt password hashing
