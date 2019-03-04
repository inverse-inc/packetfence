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
        {
            regex => qr/from: (?<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?<dstip>\d{1,3}(\.\d{1,3}){3}), mac: (?<mac>[a-fA-F0-9]{12})/,
            name => 'from to',
            last_if_match => 0,
            actions => ['modify_node: $scrip, $dstip, $mac', 'security_event_log: bob, bob'],
        },
        {
            regex => qr/from: (?<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?<dstip>\d{1,3}(\.\d{1,3}){3})/,
            name => 'from to',
            last_if_match => 1,
            actions => ['modify_node: $scrip, $dstip', 'security_event_log: bob, bob'],
        },

*/
func TestGenericParse(t *testing.T) {
	var parseTests = []ParseTest{
		{
			Line: "from: 1.2.3.4, to: 1.2.3.5, mac: aabbccddeeff",
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "modify_node",
					Params: []string{"1.2.3.4", "1.2.3.5", "aa:bb:cc:dd:ee:ff"},
				},
				&PfqueueApiCall{
					Method: "security_event_log",
					Params: []string{"bob", "bob"},
				},
			},
		},
	}

	parser, _ := NewGenericParser(&PfdetectConfig{
		Rules: []PfdetectRegexRule{
			PfdetectRegexRule{
				Regex:   `from: (?P<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?P<dstip>\d{1,3}(\.\d{1,3}){3}), mac: (?P<mac>[a-fA-F0-9]{12})`,
				Name:    "from to",
				Actions: []string{"modify_node: $scrip, $dstip, $mac", "security_event_log: bob, bob"},
			},
		},
	})
	RunParseTests(parser, parseTests, t)
}
