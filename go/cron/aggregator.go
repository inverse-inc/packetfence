package maint

import (
	"context"
	"database/sql"
	"math"
	"net/netip"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

type EventKey struct {
	DomainID  uint32
	FlowSeq   uint32
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

func updateMacs(ctx context.Context, f *PfFlow, stmt *sql.Stmt) {
	if f.SrcMac != "00:00:00:00:00:00" && f.DstMac != "00:00:00:00:00:00" {
		return
	}

	var srcMac, dstMac string
	err := stmt.QueryRowContext(ctx, f.SrcIp.String(), f.DstIp.String()).Scan(&srcMac, &dstMac)
	if err != nil {
		log.LogErrorf(ctx, "updateMacs Database Error: %s", err.Error())
	}

	if f.SrcMac == "00:00:00:00:00:00" {
		f.SrcMac = srcMac
	}

	if f.DstMac == "00:00:00:00:00:00" {
		f.DstMac = dstMac
	}
}

const updateMacsSql = `
SELECT
	COALESCE((SELECT mac FROM ip4log WHERE ip = ?), "00:00:00:00:00:00") as src_mac,
	COALESCE((SELECT mac FROM ip4log WHERE ip = ?), "00:00:00:00:00:00") as dst_mac;
`

func (a *Aggregator) handleEvents() {
	ctx := context.Background()
	ticker := time.NewTicker(a.timeout)
	stmt, err := new(sql.Stmt), error(nil)
	//	if a.db != nil {
	stmt, err = a.db.PrepareContext(ctx, updateMacsSql)
	if err != nil {
		log.LogErrorf(ctx, "handleEvents Database Error: %s %s", updateMacsSql, err.Error())
		stmt = nil
	} else {
		defer stmt.Close()
	}
	//	}

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

					if stmt != nil {
						updateMacs(ctx, &f, stmt)
					}

					a.events[key] = append(val, f)
				}
			}
		case <-ticker.C:
			networkEvents := []*NetworkEvent{}
			for _, events := range a.events {
				startTime := int64(math.MaxInt64)
				endTime := int64(0)
				connectionCount := uint64(0)
				var networkEvent *NetworkEvent
				for _, e := range events {
					networkEvent = e.ToNetworkEvent()
					if networkEvent != nil {
						break
					}
				}

				if networkEvent == nil {
					continue
				}

				ports := map[AggregatorSession]struct{}{}
				for _, e := range events {
					startTime = min(startTime, e.StartTime)
					endTime = max(endTime, e.EndTime)
					sessionKey := e.SessionKey()
					if _, ok := ports[sessionKey]; !ok {
						ports[sessionKey] = struct{}{}
						connectionCount += e.ConnectionCount
					}
				}

				networkEvent.Count = int(connectionCount)
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
