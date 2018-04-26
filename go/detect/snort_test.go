package detect

import (
	"github.com/google/go-cmp/cmp"
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
var parseTests = []struct {
	line  string
	calls []ApiCall
}{
	{
		line: "07/28/2015-09:09:59.431113  [**] [1:2221002:1] SURICATA HTTP request field missing colon [**] [Classification: Generic Protocol Command Decode] [Priority: 3] {TCP} 10.220.10.186:44196 -> 199.167.22.51:8000",
		calls: []ApiCall{
			&JsonRpcApiCall{
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

func TestSnortParse(t *testing.T) {
	parser := NewSnortParser()
	for i, test := range parseTests {
		calls, err := parser.Parse(test.line)
		if err != nil {
			t.Errorf("Error Parsing %d) %s: %v", i, test.line)
		}

		if !cmp.Equal(calls, test.calls) {
			t.Errorf("Expected ApiCall Failed for %d %v) %s", i, test.line, calls)
		}
	}
}
