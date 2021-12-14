# Inline L3

Create a Inline L3 network, start a client on this network and test.

## Requirements

### Global config steps
1. Create a Inline l3 network (network namespace, virtual ethernet interfaces, bridge and tap)

## Scenario steps
1. Create a DHCP relay configuration
1. Download and create a systemd srcipt for the DHCP relay and start it
1. Configure a inlinel3 interface as inlinel2.
1. Configure a remote inlinel3 network.
1. Create a user to use to authenticate on the portal
1. Configure interfaceSNAT (network and inline) to allow internet access for the client once registered
1. Restart services associated to inline configuration
1. Download ulinux image, install systemd service and start the client on the inline l3 network
1. Test if the client is in the unregistered ipset set
1. Authenticate on the portal
1. Test if the device is in the registered and role ID1 ipset set
1. Test internet access by trying to reach cnn.com
1. Trigger a violation on the node
1. Test if the device is in the Isolation ipset set
1. Release the violation on the node
1. Test if the device is in the registered ipset set
1. Change the role of the device to guest
1. Test if the device is in the role ID 2 ipset set

## Teardown steps
1. Stop the client and remove the systemd script
1. Set inlinel3 interface as none
1. Deconfigure interfaceSNAT (network and inline)
1. Delete user in db
1. Restart services related to inline setup
1. Stop the DHCP relay and delete the configuration
1. Remove Inline L3 network (remove network namespace, virtual ethernet interfaces and routing table)
