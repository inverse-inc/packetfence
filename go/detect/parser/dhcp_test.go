package parser

import (
	"github.com/google/go-cmp/cmp"
	"testing"
)

func TestDhcpParse(t *testing.T) {
	var parseTests = []struct {
		line  string
		calls []ApiCall
	}{
		{
			line: "Sep  1 03:27:04 172.22.0.3 dhcpd[20512]: DHCPACK to 172.19.16.171 (00:11:22:33:44:55) via eth1",
			calls: []ApiCall{
				&JsonRpcApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", "00:11:22:33:44:55",
						"ip", "172.19.16.171",
					},
				},
			},
		},
		{
			line: "Sep  1 03:27:05 172.26.0.139 dhcpd[14557]: DHCPACK on 10.16.86.122 to 00:11:22:33:44:55 (blabla-computer) via eth2 relay eth2 lease-duration 86400 (RENEW) uid 00:11:22:33:44:55",
			calls: []ApiCall{
				&JsonRpcApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", "00:11:22:33:44:55",
						"ip", "10.16.86.122",
					},
				},
			},
		},
	}
	parser := NewDhcpParser()
	for i, test := range parseTests {
		calls, err := parser.Parse(test.line)
		if err != nil {
			t.Errorf("Error Parsing %d) %s: %v", i, test.line)
			continue
		}

		if !cmp.Equal(calls, test.calls) {
			t.Errorf("Expected ApiCall Failed for %d %v) %s", i, test.line, calls)
		}
	}
}
