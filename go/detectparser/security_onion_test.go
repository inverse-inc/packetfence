package detectparser

import (
	"testing"
)

/*

my $alert = 'Oct  7 14:23:40 idsman01 securityonion_ids: 14:23:40 pid(24921)  Alert Received: 0 1 policy-violation idshalls01-eth0-7 {2016-10-07 14:23:39} 21 173773 {ET P2P Vuze BT UDP Connection} 10.6.198.173 24.122.228.33 17 10600 65344 1 2010140 6 92 92';

my $parser = pf::factory::detect::parser->new('security_onion');
my $result = $parser->parse($alert);

is($result->{date}, "2016-10-07 14:23:39");
is($result->{srcip}, "10.6.198.173");
is($result->{dstip}, "24.122.228.33");
is($result->{events}->{detect}, "2010140");
is($result->{events}->{suricata_event}, "ET P2P Vuze BT UDP Connection");


*/
func TestSecurityOnionParse(t *testing.T) {
	var parseTests = []ParseTest{
		{
			Line: `Oct  7 14:23:40 idsman01 securityonion_ids: 14:23:40 pid(24921)  Alert Received: 0 1 policy-violation idshalls01-eth0-7 {2016-10-07 14:23:39} 21 173773 {ET P2P Vuze BT UDP Connection} 10.6.198.173 24.122.228.33 17 10600 65344 1 2010140 6 92 92`,
			Calls: []ApiCall{
				&PfqueueApiCall{
					Method: "event_add",
					Params: []interface{}{
						"date", "2016-10-07 14:23:39",
						"srcip", "10.6.198.173",
						"dstip", "24.122.228.33",
						"events", map[string]interface{}{
							"suricata_event": "ET P2P Vuze BT UDP Connection",
							"detect":         "2010140",
						},
					},
				},
			},
		},
	}

	parser, _ := NewSecurityOnionParser(nil)
	RunParseTests(parser, parseTests, t)
}
