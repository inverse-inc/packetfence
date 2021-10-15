# inline L3 scenario

## Requirements
switch01 with:
- an IP address on inline L2 network to reach PacketFence
- an IP address on VLAN18 (inline L3 network) to relay DHCP requests
- a [DHCP relay](https://docs.cumulusnetworks.com/cumulus-linux-37/Layer-1-and-Switch-Ports/DHCP-Relays/)
- node02 attached to VLAN18

On switch01:

```
net add dhcp relay interface swp6
net add dhcp relay interface bridge.18
net add dhcp relay server 172.17.6.2
net pending
net commit
sudo systemctl restart dhcrelay
sudo systemctl enable dhcrelay
```

## Global config steps

## Scenario steps
- Configure inline L2 network
- Configure routed network as inline L3 with next_hop as switch01 (172.17.6.3)
- Restart all services related
- Register node02
- Apply iptables rules on switch01 to NAT traffic from inline L3 to
  bridge.100:
```
sudo iptables -t nat -A POSTROUTING -o bridge.100 -s 172.17.18.0/24  -j MASQUERADE
```
- Check Internet access on node02
- Check ipset sessions

## Teardown steps
- Switch node02 to unreg status
- Check ipset sessions
- Check Internet access on node02
- Unconfigure switch01
- Remove inline networks

## Notes

Due to L3, once iptables rules is in place, node02 is able to reach public IP
even if it's unregistered.
