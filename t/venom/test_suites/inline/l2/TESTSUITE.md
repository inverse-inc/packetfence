# Inline L2

Create a Inline L2 network, start a client on this network and test.

## Requirements

### Global config steps
1. Create a Inline l2 network (virtual ethernet interfaces, bridge and tap)

## Scenario steps
1. Enable the interface inlinel2 as a inlinel2 interface
1. Configure the network 192.168.2.0 to lower the lease time
1. Create a user to use to authenticate on the portal
1. Configure interfaceSNAT (network and inline) to allow internet access for the client once registered
1. Restart services associated to inline configuration
1. Download ulinux image, install systemd service and start the client on the inline l2 network
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
1. Set inlinel2 interface as none
1. Delete user in db
1. Deconfigure interfaceSNAT (network and inline)
1. Restart services related to inline setup
1. Remove Inline L2 network (remove virtual ethernet interfaces, bridge and tap)
