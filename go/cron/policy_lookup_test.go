package maint

import (
	"encoding/json"
	"errors"
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
			in:  "#deny udp any host 11:11:11:11:11:11 eq ",
			err: fmt.Errorf("Invalid Syntax"),
		},
		{
			in:  "#deny",
			err: fmt.Errorf("Invalid Syntax"),
		},
		{
			in:  "",
			err: fmt.Errorf("Invalid Syntax"),
		},
	}

	for _, test := range tests {
		matcher, err := ParseAcl(test.in)
		if err != nil {
			if test.err == nil {
				t.Errorf("Parse error acl '%s': %s", test.in, err.Error())
			}

			errors.Is(err, test.err)
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
