# Security Event Suricata

Create a Inline L2 network, start a client on this network apply a security suricata event, tests.

## Requirements

### Global config steps
1. Create a Inline l2 network (virtual ethernet interfaces, bridge and tap)

## Scenario steps
1. Enable the interface inlinel2 as a inlinel2 interface
1. Configure the network 192.168.3.0 to lower the lease time
1. Create a user to use to authenticate on the portal
1. Configure interfaceSNAT (network and inline) to allow internet access for the client once registered
1. Restart services associated to inline configuration
1. Download ulinux image, install systemd service and start the client on the inline l2 network
1. Test if the client is in the unregistered ipset set
1. Authenticate on the portal
1. Test if the device is in the registered and role ID1 ipset set
1. Test internet access by trying to reach cnn.com
1. Set Suricata configuration
1. Load a Suricata event and trigger the security event
1. Test if the device is in the Isolation ipset set
1. Release the security event on the node
1. Test if the device is in the registered ipset set

## Teardown steps
1. Stop the client and remove the systemd script
1. Set inlinel2 interface as none
1. Delete user in db
1. Deconfigure interfaceSNAT (network and inline)
1. Restart services related to inline setup
1. Remove Inline L2 network (remove virtual ethernet interfaces, bridge and tap)
1. Remove suricata configuration
1. Remove extra files
