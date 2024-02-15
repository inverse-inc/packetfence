package maint

import (
	"math"
	"net/netip"
	"time"
)

type EventKey struct {
	SrcIp     netip.Addr
	DstIp     netip.Addr
	DstPort   uint16
	Proto     uint8
	HasBiFlow bool
}

func NewAggregator(o *AggregatorOptions) *Aggregator {
	return &Aggregator{
		timeout:          o.Timeout,
		backlog:          1000,
		networkEventChan: o.NetworkEventChan,
		events:           make(map[EventKey][]PfFlow),
		stop:             make(chan struct{}),
		PfFlowsChan:      ChanPfFlow,
	}
}

type AggregatorOptions struct {
	NetworkEventChan chan []*NetworkEvent
	Timeout          time.Duration
}

type AggregatorSession struct {
	SessionId uint32
	Port      uint16
}

type Aggregator struct {
	events           map[EventKey][]PfFlow
	PfFlowsChan      chan []*PfFlows
	stop             chan struct{}
	networkEventChan chan []*NetworkEvent
	backlog          int
	timeout          time.Duration
}

func (a *Aggregator) handleEvents() {
	ticker := time.NewTicker(a.timeout)
loop:
	for {
		select {
		case pfflowsArray := <-ChanPfFlow:
			for _, pfflows := range pfflowsArray {
				for _, f := range *pfflows.Flows {
					key := f.Key(&pfflows.Header)
					val := a.events[key]
					a.events[key] = append(val, f)
				}
			}
		case <-ticker.C:
			networkEvents := []*NetworkEvent{}
			for _, events := range a.events {
				startTime := int64(math.MaxInt64)
				endTime := int64(0)
				networkEvent := events[0].ToNetworkEvent()
				if networkEvent == nil {
					continue
				}

				ports := map[AggregatorSession]struct{}{}
				for _, e := range events {
					startTime = min(startTime, e.StartTime)
					endTime = max(endTime, e.EndTime)
					ports[e.SessionKey()] = struct{}{}
				}

				networkEvent.Count = len(ports)
				networkEvents = append(networkEvents, networkEvent)
			}

			if len(networkEvents) > 0 && a.networkEventChan != nil {
				a.networkEventChan <- networkEvents
			}

			clear(a.events)
		case <-a.stop:
			break loop
		}
	}
}
