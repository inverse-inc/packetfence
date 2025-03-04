# wireless dot1x_eap_peap

## Requirements
AD server running

## Global config steps
1. Create access duration
1. Create dot1x roles
1. Create switches and switch groups

## Scenario steps
1. Enable node_cleanup task with following parameters:
- delete_windows=1m
1. Restart `pfcron` to take change into account
1. Join domain
1. Configure REALMS
1. Restart RADIUS services (common test suite)
1. Create and test AD sources
1. Create connection profile with auto-registration, AD sources, specific
   filter and `unreg_on_accounting_stop`
1. Perform Checkup (common test suite)
1. Configure 802.1X and dynamic VLAN on hostapd secure wlan0 wireless_secure wireless01
1. Start wpa_supplicant in background *on* wireless01
1. Wait some time to let RADIUS request be sent by wireless01 and handled by
   PacketFence server
1. Check RADIUS audit log for wireless01 wlan1
1. Check node status for wireless01 wlan1
1. Check VLAN assigned to wireless01 wlan1 *on* wireless01 wlan0

## Teardown steps
1. Kill wpa_supplicant
1. Stop service hostapd secure
1. Check online status of wireless01 wlan1: should be offline due to accounting stop
1. Check node status for wireless01 wlan1
1. Wait `delete_windows` + 10 seconds before running `node_cleanup` task
1. Delete node by running `pfcron's node_cleanup` task
1. Check node has been deleted
1. Disable `node_cleanup` task
1. Restart `pfcron` to take change into account
1. Unconfigure and delete REALMS
1. Delete domain
1. Delete connection profile
1. Delete sources
1. Stop NTLM Auth API service
1. Restart RADIUS services (common test suite)

## Additional notes

* When `wpa_supplicant` is started on wireless01, PacketFence received a
  RADIUS MAC auth request from wireless01 before receiving 802.1X request.
  
* When `hostapd` is stopped on wireless01, `wlan0.XXX` interfaces are removed.

* `hostapd` send accounting messages to PacketFence server.
