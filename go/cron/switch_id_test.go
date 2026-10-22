package maint

import (
	"encoding/json"
	"net/netip"
	"strings"
	"testing"
)

func TestSwitchID(t *testing.T) {
	tests := []struct {
		addr netip.Addr
		want string
	}{
		{netip.Addr{}, ""},
		{netip.IPv4Unspecified(), ""},
		{netip.IPv6Unspecified(), ""},
		{netip.MustParseAddr("192.168.40.19"), "192.168.40.19"},
		{netip.MustParseAddr("2001:db8::1"), "2001:db8::1"},
	}

	for _, tt := range tests {
		if got := switchID(tt.addr); got != tt.want {
			t.Errorf("switchID(%v) = %q, want %q", tt.addr, got, tt.want)
		}
	}
}

func TestEventKeySeparatesSwitches(t *testing.T) {
	f := PfFlow{
		SrcIp:   netip.MustParseAddr("1.1.1.1"),
		DstIp:   netip.MustParseAddr("1.1.1.2"),
		SrcPort: 1024,
		DstPort: 80,
		Proto:   6,
	}

	for _, biflow := range []uint8{0, 1, 2} {
		f.BiFlow = biflow
		h1 := PfFlowHeader{AgentAddr: netip.MustParseAddr("10.0.0.1")}
		h2 := PfFlowHeader{AgentAddr: netip.MustParseAddr("10.0.0.2")}
		k1, k2 := f.Key(&h1), f.Key(&h2)
		if k1 == k2 {
			t.Errorf("biflow %d: flows from different switches share a key", biflow)
		}

		if k1.AgentAddr != h1.AgentAddr {
			t.Errorf("biflow %d: key AgentAddr = %v, want %v", biflow, k1.AgentAddr, h1.AgentAddr)
		}
	}
}

func TestNetworkEventSwitchIDJSON(t *testing.T) {
	data, err := json.Marshal(&NetworkEvent{SwitchID: "192.168.40.19"})
	if err != nil {
		t.Fatal(err)
	}

	if !strings.Contains(string(data), `"switch-id":"192.168.40.19"`) {
		t.Errorf("switch-id missing from %s", data)
	}

	data, err = json.Marshal(&NetworkEvent{})
	if err != nil {
		t.Fatal(err)
	}

	if strings.Contains(string(data), "switch-id") {
		t.Errorf("empty switch-id must be omitted: %s", data)
	}
}

func TestBuildNetworkEventsSwitchID(t *testing.T) {
	flow := PfFlow{
		SrcMac:          "00:11:22:33:44:55",
		DstMac:          "00:11:22:33:44:56",
		SrcIp:           netip.MustParseAddr("1.1.1.1"),
		DstIp:           netip.MustParseAddr("1.1.1.2"),
		SrcPort:         1024,
		DstPort:         80,
		Proto:           6,
		ConnectionCount: 1,
	}

	events := map[EventKey][]PfFlow{}
	for _, agent := range []netip.Addr{netip.MustParseAddr("10.0.0.1"), netip.MustParseAddr("10.0.0.2"), {}} {
		h := PfFlowHeader{AgentAddr: agent}
		key := flow.Key(&h)
		events[key] = append(events[key], flow)
	}

	got := map[string]int{}
	for _, ne := range buildNetworkEvents(events) {
		got[ne.SwitchID]++
	}

	want := map[string]int{"10.0.0.1": 1, "10.0.0.2": 1, "": 1}
	if len(got) != len(want) {
		t.Fatalf("switch IDs = %v, want %v", got, want)
	}

	for id, n := range want {
		if got[id] != n {
			t.Fatalf("switch IDs = %v, want %v", got, want)
		}
	}
}
