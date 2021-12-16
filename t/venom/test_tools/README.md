### Go code:

To be able to use the go tools on ulinux, you have to compile with env variable CGO_ENABLED=0 go build

### DHCP Relay

A DHCP Relay server is available here http://inverse.ca/downloads/PacketFence/LiveCD/standalone_dhcp

And can be configured like this (/usr/local/etc/godhcp.ini)

```
[interfaces]
#Interfaces that act as dhcp server
listen=eth1
#Interface:Relay ip mean dhcp request received on this interface will be forwarded to the relay address.
relay=eth1.2:172.20.0.1,eth1.3:172.21.0.1

[network 192.168.1.0]
dns=8.8.8.8,8.8.4.4
next_hop=
gateway=192.168.1.1
dhcp_start=192.168.1.10
domain-name=iastigmate.org
dhcp_max_lease_time=30
dhcpd=enabled
netmask=255.255.255.0
dhcp_end=192.168.1.254
dhcp_default_lease_time=30
```

### Ulinux

As a small client you can use http://inverse.ca/downloads/PacketFence/LiveCD/ulinux.qcow2


