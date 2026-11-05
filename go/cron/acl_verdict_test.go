package maint

import (
	"context"
	"net/netip"
	"testing"
)

// The ACL pushed for the role in the RADIUS reply of a Cisco switch
// (ip:inacl#101..109).
const testPushedAcl = `permit udp any host 8.8.4.4 eq 53
permit tcp any host 8.8.4.4 eq 53
permit udp any host 8.8.8.8 eq 53
permit tcp any host 8.8.8.8 eq 53
permit udp any any eq 67
permit udp any any eq 68
deny tcp any any eq 443
deny udp any any eq 443
permit ip any any
`

const (
	testNodeMac   = "aa:bb:cc:00:00:01"
	testRemoteMac = "aa:bb:cc:00:00:02"
)

func tcpEvent(dstPort int, flags uint8, sampled bool) *NetworkEvent {
	return &NetworkEvent{
		EventType:           NetworkEventTypeSuccessful,
		SourceIp:            netip.MustParseAddr("192.0.2.20"),
		DestIp:              netip.MustParseAddr("198.51.100.163"),
		DestPort:            dstPort,
		IpProtocol:          IpProtocolTcp,
		SourceInventoryItem: macToInventoryitem(testNodeMac),
		DestInventoryitem:   macToInventoryitem(testRemoteMac),
		tcpFlags:            flags,
		sampled:             sampled,
	}
}

func testAcls(text string) map[string]*pushedAcl {
	return map[string]*pushedAcl{testNodeMac: parsePushedAcl("192.0.2.5", "User", text)}
}

func TestParsePushedAcl(t *testing.T) {
	acl := parsePushedAcl("192.0.2.5", "User", "remark dns\n"+testPushedAcl+"out|deny tcp any any eq 22\r\n\n")
	if len(acl.in) != 9 || len(acl.out) != 1 {
		t.Fatalf("got %d in and %d out entries, want 9 and 1", len(acl.in), len(acl.out))
	}

	for _, e := range append(acl.in, acl.out...) {
		if e.unknown {
			t.Fatalf("entry %d must parse: %+v", e.line, e)
		}
	}

	if last := acl.in[8]; !last.anyProto || last.matcher.Action != "permit" {
		t.Fatalf("permit ip any any must match every protocol: %+v", last.matcher)
	}

	if acl.out[0].line != 1 {
		t.Fatalf("out lines are numbered on their own, got %d", acl.out[0].line)
	}
}

func TestApplyAclVerdicts(t *testing.T) {
	ctx := context.Background()

	// The blocked HTTPS attempt as the switch exports it: SYN only.
	blocked := tcpEvent(443, TCPFlagSYN, false)
	// The switch did not enforce the ACL: the connection was established.
	leaked := tcpEvent(443, TCPFlagSYN|TCPFlagACK|TCPFlagPSH|TCPFlagFIN, false)
	// Sampled, or no TCP flags exported: the ACL still decides.
	sampled := tcpEvent(443, TCPFlagSYN|TCPFlagACK, true)
	noFlags := tcpEvent(443, 0, false)
	// Allowed by the ACL.
	web := tcpEvent(80, TCPFlagSYN|TCPFlagACK|TCPFlagPSH|TCPFlagFIN, false)
	// No ACL known for the source node.
	unknownNode := tcpEvent(443, TCPFlagSYN, false)
	unknownNode.SourceInventoryItem = macToInventoryitem("aa:bb:cc:00:00:09")
	// Already carries the enforcement info of a policy.
	policy := &EnforcementInfo{RuleID: "policy", Verdict: EnforcementVerdictAllow}
	withPolicy := tcpEvent(443, TCPFlagSYN, false)
	withPolicy.EnforcementInfo = policy

	applyAclVerdicts(ctx, []*NetworkEvent{blocked, leaked, sampled, noFlags, web, unknownNode, withPolicy}, testAcls(testPushedAcl))

	for name, ne := range map[string]*NetworkEvent{"blocked": blocked, "sampled": sampled, "noFlags": noFlags} {
		if ne.EnforcementInfo == nil || ne.EnforcementInfo.Verdict != EnforcementVerdictBlock {
			t.Errorf("%s: want verdict block, got %+v", name, ne.EnforcementInfo)
			continue
		}
		if ne.EventType != NetworkEventTypeFailed {
			t.Errorf("%s: want event type failed, got %s", name, ne.EventType)
		}
	}

	if want := "packetfence-acl:192.0.2.5:User:in:7"; blocked.EnforcementInfo.RuleID != want {
		t.Errorf("rule id: got %q want %q", blocked.EnforcementInfo.RuleID, want)
	}

	if leaked.EnforcementInfo == nil || leaked.EnforcementInfo.Verdict != EnforcementVerdictAlert || leaked.EventType != NetworkEventTypeSuccessful {
		t.Errorf("established despite a deny: want alert and successful, got %+v %s", leaked.EnforcementInfo, leaked.EventType)
	}

	for name, ne := range map[string]*NetworkEvent{"web": web, "unknownNode": unknownNode} {
		if ne.EnforcementInfo != nil || ne.EventType != NetworkEventTypeSuccessful {
			t.Errorf("%s: want no verdict, got %+v %s", name, ne.EnforcementInfo, ne.EventType)
		}
	}

	if withPolicy.EnforcementInfo != policy || withPolicy.EventType != NetworkEventTypeSuccessful {
		t.Errorf("a policy verdict must be kept, got %+v %s", withPolicy.EnforcementInfo, withPolicy.EventType)
	}
}

func TestApplyAclVerdictsFirstMatchWins(t *testing.T) {
	cases := map[string]string{
		"permit before the deny":  "permit tcp any any eq 443\ndeny tcp any any eq 443\n",
		"permit ip before":        "permit ip any any\ndeny tcp any any eq 443\n",
		"unparsed line before":    "permit tcp any any eq 443 log\ndeny tcp any any eq 443\n",
		"MAC line before":         "#permit tcp any host aa:bb:cc:00:00:03 eq 443\ndeny tcp any any eq 443\n",
		"no line matches":         "permit tcp any any eq 80\n",
		"deny for another host":   "deny tcp any host 198.51.100.1 eq 443\npermit ip any any\n",
		"deny for the other side": "out|deny tcp any any eq 443\n",
	}

	for name, text := range cases {
		ne := tcpEvent(443, TCPFlagSYN, false)
		applyAclVerdicts(context.Background(), []*NetworkEvent{ne}, testAcls(text))
		if ne.EnforcementInfo != nil || ne.EventType != NetworkEventTypeSuccessful {
			t.Errorf("%s: want no verdict, got %+v %s", name, ne.EnforcementInfo, ne.EventType)
		}
	}
}

func TestApplyAclVerdictsOutLineOfDestination(t *testing.T) {
	// Traffic to the node is checked against its out lines.
	ne := tcpEvent(22, TCPFlagSYN, false)
	ne.SourceInventoryItem, ne.DestInventoryitem = ne.DestInventoryitem, ne.SourceInventoryItem
	applyAclVerdicts(context.Background(), []*NetworkEvent{ne}, testAcls("permit ip any any\nout|deny tcp any any eq 22\n"))
	if ne.EnforcementInfo == nil || ne.EnforcementInfo.RuleID != "packetfence-acl:192.0.2.5:User:out:1" || ne.EventType != NetworkEventTypeFailed {
		t.Fatalf("want the out line to block, got %+v %s", ne.EnforcementInfo, ne.EventType)
	}
}

func TestPushedAclsWithoutDatabase(t *testing.T) {
	if acls := pushedAcls(context.Background(), nil, []string{testNodeMac}); len(acls) != 0 {
		t.Fatalf("no database: want no ACL, got %v", acls)
	}
}
