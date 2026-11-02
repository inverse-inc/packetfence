package maint

import (
	"net/netip"
	"testing"
)

func TestPfFlowHeaderSampled(t *testing.T) {
	cases := []struct {
		header PfFlowHeader
		want   bool
	}{
		{PfFlowHeader{FlowType: 10}, false},                      // IPFIX, interval not forwarded
		{PfFlowHeader{FlowType: 9, SampleInterval: 1}, false},    // every packet
		{PfFlowHeader{FlowType: 5, SampleInterval: 100}, true},   // NetFlow v5 1:100
		{PfFlowHeader{FlowType: 65535}, true},                    // sFlow
		{PfFlowHeader{FlowType: 65535, SampleInterval: 1}, true}, // sFlow
	}

	for _, c := range cases {
		if got := c.header.Sampled(); got != c.want {
			t.Errorf("%+v: got %v want %v", c.header, got, c.want)
		}
	}
}

// The flows of a blocked HTTPS attempt and of a plain HTTP request as a
// Catalyst exports them in IPFIX (biflow 1 is the initiator side, 2 the
// responder side of the same connection).
func testFlow(dstPort uint16, flags uint8, biflow uint8, sampled bool) PfFlow {
	f := PfFlow{
		SrcIp: netip.MustParseAddr("192.0.2.20"), DstIp: netip.MustParseAddr("198.51.100.163"),
		SrcMac: testNodeMac, DstMac: testRemoteMac,
		SrcPort: 46114, DstPort: dstPort,
		TCPFlags: flags, BiFlow: biflow, Proto: 6,
		PacketCount: 9, ConnectionCount: 1, Sampled: sampled,
	}
	if biflow == 2 {
		f.SrcIp, f.DstIp = f.DstIp, f.SrcIp
		f.SrcMac, f.DstMac = f.DstMac, f.SrcMac
		f.SrcPort, f.DstPort = f.DstPort, f.SrcPort
	}
	return f
}

func eventOf(t *testing.T, flows ...PfFlow) *NetworkEvent {
	t.Helper()
	header := PfFlowHeader{}
	events := map[EventKey][]PfFlow{}
	for _, f := range flows {
		events[f.Key(&header)] = append(events[f.Key(&header)], f)
	}
	built := buildNetworkEvents(events)
	if len(built) != 1 {
		t.Fatalf("want one event, got %d", len(built))
	}
	return built[0]
}

func TestBuildNetworkEventsEventType(t *testing.T) {
	const synAckPshFin = TCPFlagSYN | TCPFlagACK | TCPFlagPSH | TCPFlagFIN
	cases := []struct {
		name  string
		flows []PfFlow
		want  NetworkEventType
	}{
		{"SYN only", []PfFlow{testFlow(443, TCPFlagSYN, 1, false)}, NetworkEventTypeFailed},
		{"established", []PfFlow{testFlow(80, synAckPshFin, 1, false), testFlow(80, synAckPshFin, 2, false)}, NetworkEventTypeSuccessful},
		{"SYN only, answered on the responder side", []PfFlow{testFlow(443, TCPFlagSYN, 1, false), testFlow(443, TCPFlagSYN|TCPFlagACK, 2, false)}, NetworkEventTypeSuccessful},
		{"SYN only but sampled", []PfFlow{testFlow(443, TCPFlagSYN, 1, true)}, NetworkEventTypeSuccessful},
		{"no TCP flags exported", []PfFlow{testFlow(443, 0, 1, false)}, NetworkEventTypeSuccessful},
		{"later record of a long connection", []PfFlow{testFlow(443, TCPFlagACK|TCPFlagPSH, 1, false)}, NetworkEventTypeSuccessful},
	}

	for _, c := range cases {
		if got := eventOf(t, c.flows...).EventType; got != c.want {
			t.Errorf("%s: got %s want %s", c.name, got, c.want)
		}
	}
}

func TestBuildNetworkEventsUdpNeverFailed(t *testing.T) {
	f := testFlow(443, TCPFlagSYN, 1, false)
	f.Proto = 17
	if got := eventOf(t, f).EventType; got != NetworkEventTypeSuccessful {
		t.Fatalf("UDP has no TCP flags to judge: got %s", got)
	}
}
