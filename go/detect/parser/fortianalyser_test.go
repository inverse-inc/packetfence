package parser

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
func TestFortiAnalyserParse(t *testing.T) {
	var parseTests = []struct {
		line  string
		calls []ApiCall
	}{
		{
			line: `Mar  3 18:48:58 172.21.2.63 date=2014-03-03 time=18:49:15 devname=FortiGate-VM64 devid=FGVM010000016588 logid=0316013057 type=utm subtype=webfilter eventtype=ftgd_blk level=warning vd="root" policyid=1 identidx=0 sessionid=45421 osname="Windows" osversion="7 (x64)" srcip=172.21.5.11 srcport=2019 srcintf="port2" dstip=64.210.140.16 dstport=80 dstintf="port1" service="http" hostname="www.example.com" profiletype="Webfilter_Profile" profile="default" status="blocked" reqtype="referral" url="/test_adult_url" sentbyte=820 rcvdbyte=1448 msg="URL belongs to a category with warnings enabled" method=domain class=0 cat=14 catdesc="Pornography"`,
			calls: []ApiCall{
				&JsonRpcApiCall{
					Method: "event_add",
					Params: []interface{}{
						"srcip", "172.21.5.11",
						"events", map[string]interface{}{
							"detect": "0316013057",
						},
					},
				},
			},
		},
	}

	parser := NewFortiAnalyserParser()
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
