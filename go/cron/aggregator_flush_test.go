package maint

import (
	"net/netip"
	"testing"
)

func flowWithMacs(src, dst string, srcMac, dstMac string) PfFlow {
	return PfFlow{
		SrcIp:  netip.MustParseAddr(src),
		DstIp:  netip.MustParseAddr(dst),
		SrcMac: srcMac,
		DstMac: dstMac,
	}
}

func TestApplyResolvedMacsComplete(t *testing.T) {
	events := map[EventKey][]PfFlow{
		{}: {
			flowWithMacs("10.0.0.1", "10.0.0.2", "", ""),                                   // both resolved
			flowWithMacs("10.0.0.1", "10.0.0.9", "", ""),                                   // dst has no ip4log row
			flowWithMacs("10.0.0.3", "10.0.0.2", "aa:aa:aa:aa:aa:aa", ""),                  // src already known
			flowWithMacs("10.0.0.9", "10.0.0.8", "", "00:00:00:00:00:00"),                  // neither known
			flowWithMacs("10.0.0.3", "10.0.0.4", "aa:aa:aa:aa:aa:aa", "bb:bb:bb:bb:bb:bb"), // untouched
		},
	}
	macs := map[string]string{
		"10.0.0.1": "11:11:11:11:11:11",
		"10.0.0.2": "22:22:22:22:22:22",
	}

	applyResolvedMacs(events, macs, true)
	flows := events[EventKey{}]

	want := [][2]string{
		{"11:11:11:11:11:11", "22:22:22:22:22:22"},
		{"11:11:11:11:11:11", "00:00:00:00:00:00"}, // complete lookup: no row -> zero MAC
		{"aa:aa:aa:aa:aa:aa", "22:22:22:22:22:22"},
		{"00:00:00:00:00:00", "00:00:00:00:00:00"},
		{"aa:aa:aa:aa:aa:aa", "bb:bb:bb:bb:bb:bb"},
	}
	for i, w := range want {
		if flows[i].SrcMac != w[0] || flows[i].DstMac != w[1] {
			t.Errorf("flow %d: got %s/%s want %s/%s", i, flows[i].SrcMac, flows[i].DstMac, w[0], w[1])
		}
	}
}

func TestApplyResolvedMacsIncompleteKeepsUnknownEmpty(t *testing.T) {
	// A chunk query failed: IPs missing from the map must not be coalesced to
	// the zero MAC, otherwise ToNetworkEvent drops flows with two zero MACs
	// that the previous per-flow lookup still emitted as IP-only events.
	events := map[EventKey][]PfFlow{
		{}: {
			flowWithMacs("10.0.0.1", "10.0.0.9", "", ""),
			flowWithMacs("10.0.0.8", "10.0.0.9", "", ""),
		},
	}
	macs := map[string]string{"10.0.0.1": "11:11:11:11:11:11"}

	applyResolvedMacs(events, macs, false)
	flows := events[EventKey{}]

	if flows[0].SrcMac != "11:11:11:11:11:11" {
		t.Errorf("resolved IP must still be filled: got %q", flows[0].SrcMac)
	}
	if flows[0].DstMac != "" || flows[1].SrcMac != "" || flows[1].DstMac != "" {
		t.Errorf("unknown IPs must keep an empty MAC after a failed lookup: got %q %q %q", flows[0].DstMac, flows[1].SrcMac, flows[1].DstMac)
	}
}

func TestWindowStatsNoteAgent(t *testing.T) {
	var s windowStats // zero value, as after `stats = windowStats{}`
	s.noteAgent("10.1.1.1")
	s.noteAgent("10.1.1.1")
	s.noteAgent("10.1.1.2")
	if len(s.agents) != 2 {
		t.Fatalf("want 2 distinct agents, got %d", len(s.agents))
	}

	n := newWindowStats()
	if n.agents == nil || len(n.agents) != 0 {
		t.Fatalf("newWindowStats must start with an empty, non-nil agent set")
	}
}
