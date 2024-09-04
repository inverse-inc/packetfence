package maint

import (
	"encoding/json"
	"net/netip"
	"testing"

	"github.com/google/go-cmp/cmp"
)

func TestMatcher(t *testing.T) {
	tests := []struct {
		in  string
		out Matcher
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
	}

	for _, test := range tests {
		matcher, err := ParseAcl(test.in)
		if err != nil {
			t.Errorf("Parse error acl '%s': %s", test.in, err.Error())
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
	ne :=
		NetworkEvent{
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
  "IoT-Camera": [
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "allow",
          "dc-inventory-revision": 1724760075,
          "id": "2b484809-e2d0-452a-843b-b9f86ed757bf/"
        }
      ],
      "acls": [
        "permit tcp any any eq 156",
        "permit udp any any eq 156"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "44d57077-088f-4242-88bf-7f39f2a7c266/"
        }
      ],
      "acls": [
        "deny tcp any any eq 55",
        "deny udp any any eq 55"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "ac59c4ba-dfaa-4250-9f6f-6e95e2fcdcee/"
        }
      ],
      "acls": [
        "deny tcp any any eq 83",
        "deny udp any any eq 83"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "886f12bc-20dd-4b05-9cbc-3de4f9f07d85/"
        }
      ],
      "acls": [
        "deny tcp any host 172.17.0.71 eq 789",
        "deny udp any host 172.17.0.71 eq 789",
        "deny tcp any host 100.100.100.71 eq 789",
        "deny udp any host 100.100.100.71 eq 789",
        "deny tcp any host 200.200.200.71 eq 789",
        "deny udp any host 200.200.200.71 eq 789"
      ]
    }
  ],
  "IoT-Lighting": [
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "allow",
          "dc-inventory-revision": 1724760075,
          "id": "8ffeadeb-b4d2-4f60-a4f7-9d865a70c45e/"
        }
      ],
      "acls": [
        "permit tcp any any eq 18",
        "permit udp any any eq 18"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "allow",
          "dc-inventory-revision": 1724760075,
          "id": "63f8a3e0-e837-4662-a747-8d6b28b6b268/"
        }
      ],
      "acls": [
        "permit tcp any any eq 113",
        "permit udp any any eq 113"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "f96848da-a7ce-48d9-8f81-14c34250bb25/"
        }
      ],
      "acls": [
        "deny tcp any any eq 28",
        "deny udp any any eq 28"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "28d54f85-f3ae-4538-8ac6-5a1338762c32/"
        }
      ],
      "acls": [
        "deny tcp any host 8.8.8.8 eq 10",
        "deny udp any host 8.8.8.8 eq 10",
        "deny tcp any host 8.8.8.8 eq 11",
        "deny udp any host 8.8.8.8 eq 11",
        "deny tcp any host 8.8.8.8 eq 12",
        "deny udp any host 8.8.8.8 eq 12"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "afb391d0-a9fd-472c-ba6c-69fbaae8d67b/"
        }
      ],
      "acls": [
        "deny tcp any any eq 91",
        "deny udp any any eq 91"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "e77ca958-9a8e-4e9e-b909-11505ff4decf/"
        }
      ],
      "acls": [
        "deny tcp any any eq 99",
        "deny udp any any eq 99"
      ]
    },
    {
      "enforcement_info": [
        {
          "policy-revision": 109,
          "verdict": "block",
          "dc-inventory-revision": 1724760075,
          "id": "6524b9b0-eae5-4d37-a1f5-48400a4f437a/"
        }
      ],
      "acls": [
        "deny tcp any any eq 85",
        "deny udp any any eq 85"
      ]
    }
  ]
}
`

func TestPolicyLoad(t *testing.T) {
	lookup := make(PolicyLookup)
	err := json.Unmarshal([]byte(RolesPoliciesMapJSON), &lookup)
	if err != nil {
		t.Fatalf("json.Unmarshal: %v", err)
	}

	lookup.UpdateMatcher()
}
