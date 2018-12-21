package detectparser

import (
	"encoding/json"
	"testing"
)

/*

my $alert = 'Jul  7 15:48:02 Thierry-SecurityOnion suricata_files: { "timestamp": "07\/07\/2016-15:48:01.623845", "ipver": 4, "srcip": "104.28.13.103", "dstip": "172.20.20.211", "protocol": 6, "sp": 80, "dp": 59131, "http_uri": "\/billing\/includes\/jscript\/db\/3july2.exe", "http_host": "snthostings.com", "http_referer": "<unknown>", "http_user_agent": "Wget\/1.15 (linux-gnu)", "filename": "\/billing\/includes\/jscript\/db\/3july2.exe", "magic": "PE32 executable (GUI) Intel 80386, for MS Windows", "state": "CLOSED", "md5": "0806b949be8f93127a9fbf909221a121", "stored": false, "size": 1145856 }';
my $parser = pf::factory::detect::parser->new('suricata_md5');
my $result = $parser->_parse($alert);

ok(defined($result->{http_host}), "checking that http method is recognised so we know who is the possible infected endpoint.");
is($result->{dstip}, "172.20.20.211", "checking destination IP is properly parsed.");
is($result->{md5}, "0806b949be8f93127a9fbf909221a121", "checking that md5 is properly parsed.");

$apiclient->notify('trigger_violation', ( 'mac' => $data->{mac}, 'tid' => $data->{md5}, 'type' => 'suricata_md5' ));   # Process Suricata MD5 based violations

*/

type IPToMacTestFunc func(string) (string, error)

func (f IPToMacTestFunc) IpToMac(ip string) (string, error) {
	return f(ip)
}

func TestSuricataMD5Parse(t *testing.T) {
	testLine := `{ "timestamp": "07\/07\/2016-15:48:01.623845", "ipver": 4, "srcip": "104.28.13.103", "dstip": "172.20.20.211", "protocol": 6, "sp": 80, "dp": 59131, "http_uri": "\/billing\/includes\/jscript\/db\/3july2.exe", "http_host": "snthostings.com", "http_referer": "<unknown>", "http_user_agent": "Wget\/1.15 (linux-gnu)", "filename": "\/billing\/includes\/jscript\/db\/3july2.exe", "magic": "PE32 executable (GUI) Intel 80386, for MS Windows", "state": "CLOSED", "md5": "0806b949be8f93127a9fbf909221a121", "stored": false, "size": 1145856 }`
	var testData map[string]interface{}
	if err := json.Unmarshal([]byte(testLine), &testData); err != nil {
		t.Fatal("Bad data given cannot complete test")
		return
	}

	testData["mac"] = "00:11:22:33:44:55"

	var parseTests = []ParseTest{
		{
			Line: `Jul  7 15:48:02 Thierry-SecurityOnion suricata_files: ` + testLine,
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "trigger_violation",
					Params: []interface{}{
						"mac", "00:11:22:33:44:55",
						"tid", "0806b949be8f93127a9fbf909221a121",
						"type", "suricata_md5",
					},
				},
			},
		},
	}
	parser, _ := NewSuricataMD5Parser(nil)
	parser.(*SuricataMD5Parser).ResolverIp2Mac = IPToMacTestFunc(
		func(string) (string, error) {
			return "00:11:22:33:44:55", nil
		},
	)
	RunParseTests(parser, parseTests, t)
}
