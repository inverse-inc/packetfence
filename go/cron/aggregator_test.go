package maint

import (
	"net/netip"
	"testing"
	"time"
)

func TestAggregator(t *testing.T) {
	networkEventChan := make(chan []*NetworkEvent, 100)
	events := []*PfFlows{
		{
			Flows: &[]PfFlow{
				{
					SrcIp:   netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:   netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort: 1024,
					DstPort: 80,
					Proto:   6,
					BiFlow:  1,
				},
				{
					SrcIp:   netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:   netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort: 1025,
					DstPort: 80,
					Proto:   6,
					BiFlow:  1,
				},
				{
					SrcIp:   netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:   netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort: 1024,
					DstPort: 80,
					Proto:   6,
					BiFlow:  1,
				},
			},
		},
	}

	a := NewAggregator(
		&AggregatorOptions{
			Timeout:          10 * time.Millisecond,
			NetworkEventChan: networkEventChan,
		},
	)

	go a.handleEvents()
	a.PfFlowsChan <- events
	ne := <-networkEventChan
	if len(ne) != 1 {
		t.Fatalf("Not aggreated to a single network event")
	}

	if ne[0].Count != 2 {
		t.Fatalf("Not aggreated properly")
	}
}
