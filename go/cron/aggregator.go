package maint

import (
	"context"
	"database/sql"
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
		Heuristics:       o.Heuristics,
		db:               o.Db,
	}
}

type AggregatorOptions struct {
	NetworkEventChan chan []*NetworkEvent
	Timeout          time.Duration
	Heuristics       int
	Db               *sql.DB
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
	Heuristics       int
	db               *sql.DB
}

func (a *Aggregator) handleEvents() {
	ctx := context.Background()
	ticker := time.NewTicker(a.timeout)
loop:
	for {
		select {
		case pfflowsArray := <-ChanPfFlow:
			for _, pfflows := range pfflowsArray {
				for _, f := range *pfflows.Flows {
					key := f.Key(&pfflows.Header)
					val := a.events[key]
					if a.Heuristics > 0 {
						f.Heuristics()
					}
					a.events[key] = append(val, f)
				}
			}
		case <-ticker.C:
			networkEvents := []*NetworkEvent{}
			for _, events := range a.events {
				startTime := int64(math.MaxInt64)
				endTime := int64(0)
				packetCount := uint64(0)
				networkEvent := events[0].ToNetworkEvent()
				if networkEvent == nil {
					for _, e := range events[1:] {
						networkEvent = e.ToNetworkEvent()
						if networkEvent != nil {
							break
						}
					}
				}

				if networkEvent == nil {
					continue
				}

				for _, e := range events {
					startTime = min(startTime, e.StartTime)
					endTime = max(endTime, e.EndTime)
					packetCount += e.PacketCount
				}

				networkEvent.Count = int(packetCount)
				if startTime != 0 {
					networkEvent.StartTime = uint64(startTime)
				}

				if endTime != 0 {
					networkEvent.EndTime = uint64(endTime)
				}

				if networkEvent.EndTime == 0 {
					networkEvent.EndTime = networkEvent.StartTime
				}

				networkEvents = append(networkEvents, networkEvent)
			}

			for _, e := range networkEvents {
				e.UpdateEnforcementInfo(ctx, a.db)
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
