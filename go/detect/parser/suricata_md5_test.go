package parser

import (
	"testing"
)

/*

my $alert = 'Jul  7 15:48:02 Thierry-SecurityOnion suricata_files: { "timestamp": "07\/07\/2016-15:48:01.623845", "ipver": 4, "srcip": "104.28.13.103", "dstip": "172.20.20.211", "protocol": 6, "sp": 80, "dp": 59131, "http_uri": "\/billing\/includes\/jscript\/db\/3july2.exe", "http_host": "snthostings.com", "http_referer": "<unknown>", "http_user_agent": "Wget\/1.15 (linux-gnu)", "filename": "\/billing\/includes\/jscript\/db\/3july2.exe", "magic": "PE32 executable (GUI) Intel 80386, for MS Windows", "state": "CLOSED", "md5": "0806b949be8f93127a9fbf909221a121", "stored": false, "size": 1145856 }';
my $parser = pf::factory::detect::parser->new('suricata_md5');
my $result = $parser->_parse($alert);

ok(defined($result->{http_host}), "checking that http method is recognised so we know who is the possible infected endpoint.");
is($result->{dstip}, "172.20.20.211", "checking destination IP is properly parsed.");
is($result->{md5}, "0806b949be8f93127a9fbf909221a121", "checking that md5 is properly parsed.");


*/
func TestSuricataMD5Parse(t *testing.T) {
	var parseTests = []ParseTest{
		{
			Line: `Jul  7 15:48:02 Thierry-SecurityOnion suricata_files: { "timestamp": "07\/07\/2016-15:48:01.623845", "ipver": 4, "srcip": "104.28.13.103", "dstip": "172.20.20.211", "protocol": 6, "sp": 80, "dp": 59131, "http_uri": "\/billing\/includes\/jscript\/db\/3july2.exe", "http_host": "snthostings.com", "http_referer": "<unknown>", "http_user_agent": "Wget\/1.15 (linux-gnu)", "filename": "\/billing\/includes\/jscript\/db\/3july2.exe", "magic": "PE32 executable (GUI) Intel 80386, for MS Windows", "state": "CLOSED", "md5": "0806b949be8f93127a9fbf909221a121", "stored": false, "size": 1145856 }`,
			Calls: []ApiCall{
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

	parser := NewSuricataMD5Parser()
	RunParseTests(parser, parseTests, t)
}
