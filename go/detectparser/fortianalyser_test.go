package detectparser

import (
	"testing"
)

func TestFortiAnalyserParse(t *testing.T) {
	parser, _ := NewFortiAnalyserParser(nil)
	var parseTests = []ParseTest{
		{
			Line: `Mar  3 18:48:58 172.21.2.63 date=2014-03-03 time=18:49:15 devname=FortiGate-VM64 devid=FGVM010000016588 logid=0316013057 type=utm subtype=webfilter eventtype=ftgd_blk level=warning vd="root" policyid=1 identidx=0 sessionid=45421 osname="Windows" osversion="7 (x64)" srcip=172.21.5.11 srcport=2019 srcintf="port2" dstip=64.210.140.16 dstport=80 dstintf="port1" service="http" hostname="www.example.com" profiletype="Webfilter_Profile" profile="default" status="blocked" reqtype="referral" url="/test_adult_url" sentbyte=820 rcvdbyte=1448 msg="URL belongs to a category with warnings enabled" method=domain class=0 cat=14 catdesc="Pornography"`,
			Calls: []ApiCall{
				&PfqueueApiCall{
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
		{
			Line:  `Mar  3 18:48:58 172.21.2.63 date=2014-03-03 time=18:49:15 devname=FortiGate-VM64 devid=FGVM010000016588 logid=0316013057 type=utm subtype=webfilter eventtype=ftgd_blk level=warning vd="root" policyid=1 identidx=0 sessionid=45421 osname="Windows" osversion="7 (x64)" srcport=2019 srcintf="port2" dstip=64.210.140.16 dstport=80 dstintf="port1" service="http" hostname="www.example.com" profiletype="Webfilter_Profile" profile="default" status="blocked" reqtype="referral" url="/test_adult_url" sentbyte=820 rcvdbyte=1448 msg="URL belongs to a category with warnings enabled" method=domain class=0 cat=14 catdesc="Pornography"`,
			Calls: nil,
		},
	}
	RunParseTests(parser, parseTests, t)
}
