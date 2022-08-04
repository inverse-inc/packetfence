package detectparser

import (
	"testing"
)

/*

'dstip' => '199.167.22.51',
'srcip' => '10.220.10.186',
'events' => {
    'suricata_event' => 'SURICATA HTTP request field missing colon',
    'detect' => '2221002'
},
'date' => '07/28/2015-09:09:59.431113  [**] '

*/
func TestNexposeParse(t *testing.T) {
	var parseTests = []ParseTest{
		{
			Line: `Nov 13 11:38:09 172.20.120.70 Nexpose: 10.0.0.20 VULNERABILITY: OpenSSL SSL/TLS MITM vulnerability (CVE-2014-0224) (http-openssl-cve-2014-0224)`,
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "event_add",
					Params: []interface{}{
						"date", "Nov 13 11:38:09",
						"dstip", "10.0.0.20",
						"srcip", "172.20.120.70",
						"events", map[string]interface{}{
							"nexpose_event": "OpenSSL SSL/TLS MITM vulnerability (CVE-2014-0224) (http-openssl-cve-2014-0224)",
						},
					},
				},
			},
		},
	}

	parser, _ := NewNexposeParser(nil)
	RunParseTests(parser, parseTests, t)
}
