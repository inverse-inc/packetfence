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
func TestSnortParse(t *testing.T) {
	var parseTests = []ParseTest{
		{
			Line: "07/28/2015-09:09:59.431113  [**] [1:2221002:1] SURICATA HTTP request field missing colon [**] [Classification: Generic Protocol Command Decode] [Priority: 3] {TCP} 10.220.10.186:44196 -> 199.167.22.51:8000",
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "event_add",
					Params: []interface{}{
						"date", "07/28/2015-09:09:59.431113  [**] ",
						"dstip", "199.167.22.51",
						"srcip", "10.220.10.186",
						"events", map[string]interface{}{
							"suricata_event": "SURICATA HTTP request field missing colon",
							"detect":         "2221002",
						},
					},
				},
			},
		},
	}

	parser, _ := NewSnortParser(nil)
	RunParseTests(parser, parseTests, t)
}
