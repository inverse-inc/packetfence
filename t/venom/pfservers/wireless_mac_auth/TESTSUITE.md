# wireless_mac_auth

Register a node with RADIUS in order to test MAC Authentication on Wireless

## Requirements

### Global config steps
1. Create a role headless_device
1. Create switches and switch groups with role mapping

## Scenario steps
1. Enable node_cleanup task with following parameters:
- delete_windows=1m
1. Restart `pfcron` to take change into account
1. Create a node with MAC address of wireless01 (wlan1) : 02:00:00:00:01:00
- assign the role headless_device without unreg date
- add a note
1. Create connection profile with specific filter Wireless-802.11-NoEAP
1. Configure MAC authentication and dynamic VLAN on dot1x interface on
   wireless01: launch hostapd_open
1. Wait some time to let hostapd_open running
1. Enable WPA supplicant on wireless01
1. Wait some time to let RADIUS request be sent by wireless01 and handled by
   PacketFence server. wireless01 also needs to handle answer.
1. Check RADIUS audit log for wireless01 wlan1
1. Check VLAN assigned to wireless01 *on* wlan0 this the tag id

## Teardown steps
1. Unregister wireless01 (wlan1)
1. Stop wpa_supplicant then hostapd on wireless01
1. Delete node by running `pfcron's node_cleanup` task
1. Check node has been deleted
1. Disable `node_cleanup` task
1. Restart `pfcron` to take change into account
1. Delete connection profile
