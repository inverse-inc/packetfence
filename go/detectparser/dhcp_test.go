package detectparser

import (
	"testing"
)

func TestDhcpParse(t *testing.T) {
	parser, _ := NewDhcpParser(nil)
	var parseTests = []ParseTest{
		{
			Line: "Sep  1 03:27:04 172.22.0.3 dhcpd[20512]: DHCPACK to 172.19.16.171 (00:11:22:33:44:55) via eth1",
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", "00:11:22:33:44:55",
						"ip", "172.19.16.171",
					},
				},
			},
		},
		{
			Line: "Sep  1 03:27:05 172.26.0.139 dhcpd[14557]: DHCPACK on 10.16.86.122 to 00:11:22:33:44:55 (blabla-computer) via eth2 relay eth2 lease-duration 86400 (RENEW) uid 00:11:22:33:44:55",
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", "00:11:22:33:44:55",
						"ip", "10.16.86.122",
					},
				},
			},
		},
	}
	RunParseTests(parser, parseTests, t)
}
