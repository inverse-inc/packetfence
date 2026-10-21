package detectparser

import (
	"testing"
)

func TestFortiGateDhcpParse(t *testing.T) {
	parser, _ := NewFortiGateDhcpParser(nil)
	var parseTests = []ParseTest{
		{
			Line: `date=2024-12-24 time=11:56:25 devname="FGT50E3U16014289" devid="FGT50E3U16014289" logid="0100026001" type="event" subtype="system" level="information" vd="root" eventtime=1735059387564643583 tz="-0500" logdesc="DHCP Ack log" interface="VLAN_41" dhcp_msg="Ack" mac="B0:2A:43:C1:97:DC" ip=192.168.41.249 lease=300 hostname="Laptop" msg="DHCP server sends a DHCPACK"`,
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", "b0:2a:43:c1:97:dc",
						"ip", "192.168.41.249",
						"lease_length", "300",
					},
				},
				&PfqueueApiCall{
					Method: "modify_node",
					Params: []interface{}{
						"mac", "b0:2a:43:c1:97:dc",
						"computername", "Laptop",
					},
				},
			},
		},
		{
			Line:  `date=2024-12-24 time=11:56:25 devname="FGT50E3U16014289" devid="FGT50E3U16014289" logid="0100026001" type="event" subtype="system" level="information" vd="root" eventtime=1735059387564643583 tz="-0500" logdesc="DHCP Ack log" interface="VLAN_41" dhcp_msg="Nak" mac="B0:2A:43:C1:97:DC" ip=192.168.41.249 lease=300 hostname="Laptop" msg="DHCP server sends a DHCPACK"`,
			Calls: nil,
		},
	}
	RunParseTests(parser, parseTests, t)
}
