package maint

import (
	"net/netip"
	"testing"
	"time"
)

func TestAggregator(t *testing.T) {
	networkEventChan := make(chan []*NetworkEvent, 100)
	db, _ := getDb()
	events := []*PfFlows{
		{
			Header: PfFlowHeader{
				DomainID: 1,
				FlowSeq:  1,
			},
			Flows: &[]PfFlow{
				{
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					SrcPort:         80,
					DstPort:         1025,
					Proto:           6,
					BiFlow:          2,
					ConnectionCount: 2,
				},
				{
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort:         1024,
					DstPort:         80,
					Proto:           6,
					BiFlow:          1,
					ConnectionCount: 2,
				},
				{
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					SrcPort:         80,
					DstPort:         1024,
					Proto:           6,
					BiFlow:          2,
					ConnectionCount: 2,
				},
				{
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort:         1025,
					DstPort:         80,
					Proto:           6,
					BiFlow:          1,
					ConnectionCount: 2,
				},
			},
		},
	}

	a := NewAggregator(
		&AggregatorOptions{
			Timeout:          10 * time.Millisecond,
			NetworkEventChan: networkEventChan,
			Db:               db,
		},
	)

	go a.handleEvents()
	a.PfFlowsChan <- events
	ne := <-networkEventChan
	if len(ne) != 1 {
		t.Fatalf("Not aggreated to a single network event")
	}

	if ne[0].Count != 4 {
		t.Fatalf("Not aggreated properly got %d expected %d", ne[0].Count, 4)
	}

	if ne[0].DestPort != 80 {
		t.Fatalf("Not aggreated DestPort")
	}

	if ne[0].DestIp != netip.AddrFrom4([4]byte{1, 1, 1, 2}) {
		t.Fatalf("Not aggreated DestIp")
	}

	if ne[0].SourceIp != netip.AddrFrom4([4]byte{1, 1, 1, 1}) {
		t.Fatalf("Not aggreated SrcIp")
	}

	events = []*PfFlows{
		{
			Flows: &[]PfFlow{
				{
					SrcIp:   netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:   netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort: 1024,
					DstPort: 80,
					Proto:   6,
					BiFlow:  0,
				},
				{
					SrcIp:   netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:   netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort: 1025,
					DstPort: 80,
					Proto:   6,
					BiFlow:  0,
				},
				{
					SrcIp:   netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:   netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort: 1024,
					DstPort: 80,
					Proto:   6,
					BiFlow:  0,
				},
			},
		},
	}
	a.PfFlowsChan <- events
	ne = <-networkEventChan
	if len(ne) != 1 {
		t.Fatalf("Not aggreated to a single network event")
	}

	if ne[0].Count != 0 {
		t.Fatalf("Not aggreated properly")
	}

	if ne[0].DestPort != 80 {
		t.Fatalf("Not aggreated DestPort")
	}

}
