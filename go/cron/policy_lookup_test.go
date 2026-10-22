package maint

import (
	"context"
	"encoding/json"
	"fmt"
	"net/netip"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/inverse-inc/go-utils/mac"
)

func TestMatcher(t *testing.T) {
	tests := []struct {
		in  string
		out Matcher
		err error
	}{
		{

			in: "permit tcp any any",
			out: Matcher{

				Action: "permit",
				Proto:  IpProtocol("tcp"),
				Port:   0,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "",
			},
		},
		{

			in: "permit tcp any any #Supports comments",
			out: Matcher{

				Action: "permit",
				Proto:  IpProtocol("tcp"),
				Port:   0,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "",
			},
		},
		{

			in: "permit tcp any any #Supports #comments",
			out: Matcher{

				Action: "permit",
				Proto:  IpProtocol("tcp"),
				Port:   0,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "",
			},
		},
		{

			in: "permit tcp any any eq 18",
			out: Matcher{

				Action: "permit",
				Proto:  IpProtocol("tcp"),
				Port:   18,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{

			in: "permit udp any any eq 18",
			out: Matcher{
				Action: "permit",
				Proto:  IpProtocol("udp"),
				Port:   18,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "permit tcp any any eq 113",
			out: Matcher{
				Action: "permit",
				Proto:  IpProtocol("tcp"),
				Port:   113,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "permit udp any any eq 113",
			out: Matcher{
				Action: "permit",
				Proto:  IpProtocol("udp"),
				Port:   113,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any any eq 28",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   28,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny udp any any eq 28",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   28,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any host 8.8.8.8 eq 10",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   10,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("8.8.8.8" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny udp any host 8.8.8.8 eq 10",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   10,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("8.8.8.8" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any host 8.8.8.8 eq 11",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   11,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("8.8.8.8" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny udp any host 8.8.8.8 eq 11",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   11,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("8.8.8.8" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any host 8.8.8.8 eq 12",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   12,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("8.8.8.8" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny udp any host 8.8.8.8 eq 12",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   12,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("8.8.8.8" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any any eq 91",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   91,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny udp any any eq 91",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   91,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any any eq 99",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   99,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny udp any any eq 99",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   99,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any any eq 85",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   85,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny udp any any eq 85",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   85,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "permit tcp any any eq 156",
			out: Matcher{
				Action: "permit",
				Proto:  IpProtocol("tcp"),
				Port:   156,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "permit udp any any eq 156",
			out: Matcher{
				Action: "permit",
				Proto:  IpProtocol("udp"),
				Port:   156,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any any eq 55",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   55,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny udp any any eq 55",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   55,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any any eq 83",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   83,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny udp any any eq 83",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   83,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any host 172.17.0.71 eq 789",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("172.17.0.71" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny udp any host 172.17.0.71 eq 789",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("172.17.0.71" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any host 100.100.100.71 eq 789",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("100.100.100.71" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny udp any host 100.100.100.71 eq 789",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("100.100.100.71" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny tcp any host 200.200.200.71 eq 789",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("tcp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("200.200.200.71" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny udp any host 200.200.200.71 eq 789",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("200.200.200.71" + "/32"),
				Op:     "eq",
			},
		},
		{
			in: "deny udp any 200.200.201.0 0.0.0.255 eq 789",
			out: Matcher{
				Action: "deny",
				Proto:  IpProtocol("udp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: netip.MustParsePrefix("200.200.201.0" + "/24"),
				Op:     "eq",
			},
		},
		{
			in: "#deny udp any host 11:11:11:11:11:11 eq 789",
			out: Matcher{
				Action: "deny",
				DstMac: mac.Mac{0x11, 0x11, 0x11, 0x11, 0x11, 0x11},
				Proto:  IpProtocol("udp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in: "#deny udp any host 11:11:11:11:11:11 eq 789 # Comment",
			out: Matcher{
				Action: "deny",
				DstMac: mac.Mac{0x11, 0x11, 0x11, 0x11, 0x11, 0x11},
				Proto:  IpProtocol("udp"),
				Port:   789,
				SrcNet: AnyPrefix,
				DstNet: AnyPrefix,
				Op:     "eq",
			},
		},
		{
			in:  "#deny udp any host 11:11:11:11:11:11 eq ",
			err: fmt.Errorf("Invalid Syntax: '#deny udp any host 11:11:11:11:11:11 eq '"),
		},
		{
			in:  "#deny",
			err: fmt.Errorf("Invalid Syntax: '#deny'"),
		},
		{
			in:  "",
			err: fmt.Errorf("Invalid Syntax: ''"),
		},
	}

	for _, test := range tests {
		matcher, err := ParseAcl(test.in)
		if err != nil {
			if test.err == nil {
				t.Errorf("Parse error acl '%s': %s", test.in, err.Error())
			} else if err.Error() != test.err.Error() {
				t.Errorf("Parse acl '%s' error is '%s' expected '%s'", test.in, err.Error(), test.err.Error())
			}

			continue
		}

		if test.err != nil {
			t.Errorf("Parse acl '%s' succeeded expected error '%s'", test.in, test.err.Error())
			continue
		}

		if diff := cmp.Diff(
			matcher,
			test.out,
			cmp.Comparer(
				func(a, b netip.Prefix) bool {
					return a.String() == b.String()
				},
			),
		); diff != "" {
			t.Fatalf("Matcher does not match %s", diff)
		}
	}
}

func TestMatchNetworkEvent(t *testing.T) {

	tests := []struct {
		acl     string
		event   NetworkEvent
		matches bool
	}{
		{
			"permit tcp any host 10.0.0.3 eq 18",
			NetworkEvent{
				DestPort:   18,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolTcp,
			},
			true,
		},
		{
			"permit tcp any any eq 18",
			NetworkEvent{
				DestPort:   18,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolTcp,
			},
			true,
		},
		{
			"permit tcp any any",
			NetworkEvent{
				DestPort:   12,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolTcp,
			},
			true,
		},
		{
			"permit tcp any 10.0.0.0 0.0.0.255 eq 18",
			NetworkEvent{
				DestPort:   18,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolTcp,
			},
			true,
		},
		{
			"permit tcp any 10.0.0.0 0.0.0.255 eq 18",
			NetworkEvent{
				DestPort:   19,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolTcp,
			},
			false,
		},
		{
			"permit udp any 10.0.0.0 0.0.0.255 eq 19",
			NetworkEvent{
				DestPort:   19,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolUdp,
			},
			true,
		},
		{
			"#permit udp any host 11:11:11:11:11:11 eq 19",
			NetworkEvent{
				DestPort:   19,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolUdp,
				DestInventoryitem: &InventoryItem{
					ExternalIDS: []string{"11:11:11:11:11:11"},
				},
			},
			true,
		},
		{
			"#permit udp any host 11:11:11:11:11:11 eq 19",
			NetworkEvent{
				DestPort:   19,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolUdp,
				DestInventoryitem: &InventoryItem{
					ExternalIDS: []string{"11:11:11:11:11:12"},
				},
			},
			false,
		},
		{
			"permit tcp any any eq 0",
			NetworkEvent{
				DestPort:   22,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolTcp,
			},
			false,
		},
		{
			"deny tcp any any",
			NetworkEvent{
				DestPort:   22,
				SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
				IpProtocol: IpProtocolTcp,
			},
			false,
		},
	}

	for _, test := range tests {
		matcher, err := ParseAcl(test.acl)
		if err != nil {
			t.Fatalf("Error parsing acl %s", err.Error())
		}

		if matcher.Matches(&test.event) != test.matches {
			t.Fatalf("Acl did not match network event: Matcher %v", matcher)
		}
	}

	ne := NetworkEvent{
		DestPort:   18,
		SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
		DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
		IpProtocol: IpProtocolTcp,
	}

	matcher, _ := ParseAcl("permit tcp any host 10.0.0.3 eq 18")
	if !matcher.Matches(&ne) {
		t.Fatalf("Acl did not match network event")
	}

	matcher, _ = ParseAcl("permit tcp any 10.0.0.0 0.0.0.255 eq 18")
	if !matcher.Matches(&ne) {
		t.Fatalf("Acl did not match network event")
	}

	// A catch-all deny must not attribute the flow to its policy.
	policies := []Policy{
		{
			EnforcementInfo: []EnforcementInfo{{RuleID: "AAAA", Verdict: "allow"}},
			Acls:            []string{"permit tcp any any eq 443", "deny tcp any any"},
		},
		{
			EnforcementInfo: []EnforcementInfo{{RuleID: "BBBB", Verdict: "block"}},
			Acls:            []string{"permit tcp any any eq 22"},
		},
	}
	for i := range policies {
		policies[i].UpdateMatchers()
	}

	ne.DestPort = 22
	ei := matchEnforcementInfo(policies, &ne)
	if ei == nil || ei.RuleID != "BBBB" {
		t.Fatalf("Expected rule-id BBBB, got %v", ei)
	}

}

const RolesPoliciesMapJSON = `
{
  "ByRoles": {
    "IoT-Lighting": [
      {
        "enforcement_info": [
          {
            "policy-revision": 3,
            "verdict": "allow",
            "dc-inventory-revision": 1725462233,
            "rule-id": "0455792c-257b-46dd-95fd-12d5fcec26f0/"
          }
        ],
        "acls": [
          "permit tcp any any eq 22",
          "permit udp any any eq 22",
          "permit tcp any any eq 80",
          "permit udp any any eq 80",
          "permit tcp any any eq 443",
          "permit udp any any eq 443"
        ]
      },
      {
        "enforcement_info": [
          {
            "policy-revision": 3,
            "verdict": "allow",
            "dc-inventory-revision": 1725462233,
            "rule-id": "28477cf7-234e-4751-8ced-542464017b1c/"
          }
        ],
        "acls": [
          "permit tcp any 10.15.1.0 0.0.0.255 eq 3389",
          "permit udp any 10.15.1.0 0.0.0.255 eq 3389"
        ]
      },
      {
        "enforcement_info": [
          {
            "policy-revision": 3,
            "verdict": "allow",
            "dc-inventory-revision": 1725462233,
            "rule-id": "28477cf7-234e-4751-8ced-542464017b1c/"
          }
        ],
        "acls": [
          "permit tcp any 10.15.1.0 0.0.0.255 eq 3389",
          "permit udp any 10.15.1.0 0.0.0.255 eq 3389"
        ]
      },
      {
        "enforcement_info": [
          {
            "policy-revision": 66,
            "verdict": "allow",
            "dc-inventory-revision": 1727715416,
            "rule-id": "d2cdcbd9-5acd-4021-ba96-fdecbbf77473/"
          }
        ],
        "acls": [
          "#permit tcp any host 00:50:56:9d:44:ca eq 222",
          "#permit udp any host 00:50:56:9d:44:ca eq 222",
          "#permit tcp any host 00:50:56:9d:44:ca eq 333",
          "#permit udp any host 00:50:56:9d:44:ca eq 333"
        ]
      }
    ]
  },
  "ImplictPolices": [
    {
      "enforcement_info": [
        {
          "policy-revision": 3,
          "verdict": "allow",
          "dc-inventory-revision": 1725462233,
          "rule-id": "IOT IMPLICIT DNS/IOT IMPLICIT RULES"
        }
      ],
      "acls": [
        "permit udp any host 8.8.8.8 eq 53",
        "permit tcp any host 8.8.8.8 eq 53",
        "permit udp any host 8.8.4.4 eq 53",
        "permit tcp any host 8.8.4.4 eq 53"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 3,
          "verdict": "allow",
          "dc-inventory-revision": 1725462233,
          "rule-id": "IOT IMPLICIT DHCP/IOT IMPLICIT RULES"
        }
      ],
      "acls": [
        "permit udp any any eq 67",
        "permit udp any any eq 68"
      ]
    }
  ]
}
`

const RolesPoliciesMapJSON2 = `
{
  "ByRoles": {
    "Camera": [
      {
        "enforcement_info": [
          {
            "policy-revision": 5,
            "verdict": "allow",
            "dc-inventory-revision": 1789490934,
            "rule-id": "87eefb01-d99f-4e16-81c9-8b81e94b7cb1/rule1"
          }
        ],
        "acls": [
          "permit tcp any any",
          "permit udp any any"
        ]
      },
      {
        "enforcement_info": [
          {
            "policy-revision": 5,
            "verdict": "allow",
            "dc-inventory-revision": 1789490934,
            "rule-id": "e15f009c-7179-4ad4-a759-e0d8846d90a6/rule2"
          }
        ],
        "acls": [
          "permit tcp any any eq 443",
          "permit udp any any eq 443"
        ]
      }
    ]
  },
  "ImplictPolices": [
    {
      "enforcement_info": [
        {
          "policy-revision": 5,
          "verdict": "allow",
          "dc-inventory-revision": 1789490934,
          "rule-id": "implicit IOT DNS/IMPLICIT IOT RULES"
        }
      ],
      "acls": [
        "permit udp any host 8.8.8.8 eq 53",
        "permit tcp any host 8.8.8.8 eq 53",
        "permit udp any host 8.8.4.4 eq 53",
        "permit tcp any host 8.8.4.4 eq 53"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 5,
          "verdict": "allow",
          "dc-inventory-revision": 1789490934,
          "rule-id": "implicit IOT DHCP/IMPLICIT IOT RULES"
		 }
      ],
      "acls": [
        "permit udp any any eq 67",
        "permit udp any any eq 68"
      ]
    }
  ],
  "NodesPolicies": {}
}
`

func TestPolicyLoad(t *testing.T) {
	lookup := PolicyLookup{}
	err := json.Unmarshal([]byte(RolesPoliciesMapJSON), &lookup)
	if err != nil {
		t.Fatalf("json.Unmarshal: %v", err)
	}

	lookup.UpdateMatchers()
	ne := NetworkEvent{
		DestPort:   222,
		SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
		DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
		IpProtocol: IpProtocolUdp,
		DestInventoryitem: &InventoryItem{
			ExternalIDS: []string{"00:50:56:9d:44:ca"},
		},
	}

	if diff := cmp.Diff(
		lookup.LookupByRoles("IoT-Lighting", &ne),
		&EnforcementInfo{
			RuleID:              "d2cdcbd9-5acd-4021-ba96-fdecbbf77473/",
			Verdict:             "allow",
			PolicyRevision:      66,
			DcInventoryRevision: 1727715416,
		},
	); diff != "" {
		t.Fatalf("LookupByRoles does not match %s", diff)
	}

}

/*
func TestPolicyLookup(t *testing.T) {
	lookup := PolicyLookup{}
	err := json.Unmarshal([]byte(RolesPoliciesMapJSON2), &lookup)
	if err != nil {
		t.Fatalf("json.Unmarshal: %v", err)
	}

	lookup.UpdateMatchers()
	ne := NetworkEvent{
		DestPort:   222,
		SourceIp:   netip.AddrFrom4([4]byte{10, 0, 0, 1}),
		DestIp:     netip.AddrFrom4([4]byte{10, 0, 0, 3}),
		IpProtocol: IpProtocolUdp,
		DestInventoryitem: &InventoryItem{
			ExternalIDS: []string{"00:50:56:9d:44:ca"},
		},
	}

	if diff := cmp.Diff(
		lookup.LookupByRoles("IoT-Lighting", &ne),
		&EnforcementInfo{
			RuleID:              "d2cdcbd9-5acd-4021-ba96-fdecbbf77473/",
			Verdict:             "allow",
			PolicyRevision:      66,
			DcInventoryRevision: 1727715416,
		},
	); diff != "" {
		t.Fatalf("LookupByRoles does not match %s", diff)
	}

}
*/

func TestRoleKeyIsCaseInsensitive(t *testing.T) {
	// node.mac is compared case-insensitively by MariaDB but a Go map is not;
	// MACs filled in from ip4log keep whatever case the writer used.
	if roleKey("AA:BB:CC:DD:EE:FF") != roleKey("aa:bb:cc:dd:ee:ff") {
		t.Fatal("roleKey must normalize case")
	}
	if roleKey("aa:bb:cc:dd:ee:ff") != "aa:bb:cc:dd:ee:ff" {
		t.Fatal("roleKey must leave a lower-case MAC unchanged")
	}
}

func TestUpdateNetworkEventsWithoutDatabase(t *testing.T) {
	// No database: roles resolve to "" and the lookup must still run (and not
	// panic) so that MAC/implicit policies keep applying.
	StorePolicyLookup(&PolicyLookup{}) // no pfconfig in unit tests
	ne := &NetworkEvent{
		SourceInventoryItem: &InventoryItem{ExternalIDS: []string{"AA:BB:CC:DD:EE:01"}},
		DestInventoryitem:   &InventoryItem{ExternalIDS: []string{"aa:bb:cc:dd:ee:02"}},
	}
	UpdateNetworkEvents(context.Background(), nil, []*NetworkEvent{ne})
	if ne.EnforcementInfo != nil {
		t.Fatalf("no policies loaded: expected no enforcement info, got %+v", ne.EnforcementInfo)
	}
}

// TestApplyEnforcementIncompleteRolesSkipsRolePolicies covers the degraded
// path taken when a node-role chunk query failed: MAC policies still apply,
// role-based and implicit policies do not, since the role that would select
// them may simply be missing from the map.
func TestApplyEnforcementIncompleteRolesSkipsRolePolicies(t *testing.T) {
	rolePolicy := Policy{
		EnforcementInfo: []EnforcementInfo{{RuleID: "role", Verdict: "allow"}},
		Acls:            []string{"permit tcp any any"},
	}
	macPolicy := Policy{
		EnforcementInfo: []EnforcementInfo{{RuleID: "mac", Verdict: "allow"}},
		Acls:            []string{"permit tcp any any"},
	}
	implicit := Policy{
		EnforcementInfo: []EnforcementInfo{{RuleID: "implicit", Verdict: "deny"}},
		Acls:            []string{"permit tcp any any"},
	}
	lookup := &PolicyLookup{
		ByRoles:        map[string][]Policy{"IoT": {rolePolicy}},
		NodesPolicies:  map[string][]Policy{"aa:bb:cc:dd:ee:02": {macPolicy}},
		ImplictPolices: []Policy{implicit},
	}
	lookup.UpdateMatchers()

	newEvents := func() (byRole, byMac *NetworkEvent) {
		byRole = &NetworkEvent{
			SourceIp: netip.AddrFrom4([4]byte{10, 0, 0, 1}), DestIp: netip.AddrFrom4([4]byte{10, 0, 0, 2}), IpProtocol: IpProtocolTcp,
			SourceInventoryItem: &InventoryItem{ExternalIDS: []string{"aa:bb:cc:dd:ee:01"}},
		}
		byMac = &NetworkEvent{
			SourceIp: netip.AddrFrom4([4]byte{10, 0, 0, 3}), DestIp: netip.AddrFrom4([4]byte{10, 0, 0, 4}), IpProtocol: IpProtocolTcp,
			SourceInventoryItem: &InventoryItem{ExternalIDS: []string{"aa:bb:cc:dd:ee:02"}},
		}
		return
	}
	roles := map[string]string{"aa:bb:cc:dd:ee:01": "IoT"}

	byRole, byMac := newEvents()
	applyEnforcement(lookup, []*NetworkEvent{byRole, byMac}, roles, true)
	if byRole.EnforcementInfo == nil || byRole.EnforcementInfo.RuleID != "role" {
		t.Fatalf("complete roles: expected the role policy, got %+v", byRole.EnforcementInfo)
	}
	if byMac.EnforcementInfo == nil || byMac.EnforcementInfo.RuleID != "mac" {
		t.Fatalf("complete roles: expected the MAC policy, got %+v", byMac.EnforcementInfo)
	}

	// A chunk failed: the role map is (possibly) missing entries. The event
	// whose node is not in the map must get neither the implicit policy nor a
	// guess; the MAC policy is unaffected.
	byRole, byMac = newEvents()
	applyEnforcement(lookup, []*NetworkEvent{byRole, byMac}, map[string]string{}, false)
	if byRole.EnforcementInfo != nil {
		t.Fatalf("incomplete roles: expected no enforcement info, got %+v", byRole.EnforcementInfo)
	}
	if byMac.EnforcementInfo == nil || byMac.EnforcementInfo.RuleID != "mac" {
		t.Fatalf("incomplete roles: expected the MAC policy, got %+v", byMac.EnforcementInfo)
	}
}
