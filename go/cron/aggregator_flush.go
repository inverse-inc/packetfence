package maint

import (
	"cmp"
	"context"
	"database/sql"
	"math"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// windowStats counts what the aggregator ingested during one flush interval.
type windowStats struct {
	messages int
	flows    int
}

// flushBatch is one interval's worth of aggregated flows handed to the flusher.
type flushBatch struct {
	events   map[EventKey][]PfFlow
	stats    windowStats
	tickedAt time.Time
}

// flusher turns each batch into network events off the ingest goroutine so
// that Kafka consumption keeps going while the (DB heavy) flush runs.
func (a *Aggregator) flusher(ctx context.Context) {
	for batch := range a.flushChan {
		a.flush(ctx, batch)
	}
}

func (a *Aggregator) flush(ctx context.Context, batch flushBatch) {
	start := time.Now()
	ipsLookedUp := resolveMissingMacs(ctx, a.db, batch.events)
	macDone := time.Now()

	networkEvents := buildNetworkEvents(batch.events)
	buildDone := time.Now()

	UpdateNetworkEvents(ctx, a.db, networkEvents)
	rolesDone := time.Now()

	if len(networkEvents) > 0 && a.networkEventChan != nil {
		a.networkEventChan <- networkEvents
	}

	log.LogInfof(
		ctx,
		"pfflow aggregator: %d messages, %d flows, %d keys -> %d network events (ip4log lookups %d in %s, aggregate %s, policy lookup %s, total %s, queued %s)",
		batch.stats.messages, batch.stats.flows, len(batch.events), len(networkEvents),
		ipsLookedUp, macDone.Sub(start).Round(time.Millisecond),
		buildDone.Sub(macDone).Round(time.Millisecond),
		rolesDone.Sub(buildDone).Round(time.Millisecond),
		time.Since(start).Round(time.Millisecond),
		start.Sub(batch.tickedAt).Round(time.Millisecond),
	)
}

// buildNetworkEvents collapses each aggregation key into one network event.
func buildNetworkEvents(events map[EventKey][]PfFlow) []*NetworkEvent {
	networkEvents := make([]*NetworkEvent, 0, len(events))
	for _, flows := range events {
		startTime := int64(math.MaxInt64)
		endTime := int64(0)
		connectionCount := uint64(0)
		var networkEvent *NetworkEvent
		for i := range flows {
			networkEvent = flows[i].ToNetworkEvent()
			if networkEvent != nil {
				break
			}
		}

		if networkEvent == nil {
			continue
		}

		ports := map[AggregatorSession]struct{}{}
		for i := range flows {
			e := &flows[i]
			startTime = min(startTime, e.StartTime)
			endTime = max(endTime, e.EndTime)
			sessionKey := e.SessionKey()
			if _, ok := ports[sessionKey]; !ok {
				ports[sessionKey] = struct{}{}
				connectionCount += e.ConnectionCount
			}
		}

		networkEvent.Count = cmp.Or(int(connectionCount), len(ports))
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

	return networkEvents
}

const ip4logLookupChunk = 1000

// resolveMissingMacs fills in empty src/dst MACs from ip4log with one query
// per chunk of distinct IPs instead of one query per flow. IPs without an
// ip4log entry get the zero MAC, matching the previous per-flow COALESCE.
// Returns the number of distinct IPs looked up.
func resolveMissingMacs(ctx context.Context, dbh *sql.DB, events map[EventKey][]PfFlow) int {
	if dbh == nil {
		return 0
	}

	ipSet := map[string]struct{}{}
	for _, flows := range events {
		for i := range flows {
			f := &flows[i]
			if !emptyMac(f.SrcMac) && !emptyMac(f.DstMac) {
				continue
			}

			if emptyMac(f.SrcMac) && f.SrcIp.IsValid() {
				ipSet[f.SrcIp.String()] = struct{}{}
			}

			if emptyMac(f.DstMac) && f.DstIp.IsValid() {
				ipSet[f.DstIp.String()] = struct{}{}
			}
		}
	}

	macs := map[string]string{}
	if len(ipSet) > 0 {
		ips := make([]string, 0, len(ipSet))
		for ip := range ipSet {
			ips = append(ips, ip)
		}

		macs = lookupIp4logMacs(ctx, dbh, ips)
	}

	for _, flows := range events {
		for i := range flows {
			f := &flows[i]
			if !emptyMac(f.SrcMac) && !emptyMac(f.DstMac) {
				continue
			}

			if emptyMac(f.SrcMac) {
				f.SrcMac = cmp.Or(macs[f.SrcIp.String()], "00:00:00:00:00:00")
			}

			if emptyMac(f.DstMac) {
				f.DstMac = cmp.Or(macs[f.DstIp.String()], "00:00:00:00:00:00")
			}
		}
	}

	return len(ipSet)
}

func lookupIp4logMacs(ctx context.Context, dbh *sql.DB, ips []string) map[string]string {
	macs := make(map[string]string, len(ips))
	for start := 0; start < len(ips); start += ip4logLookupChunk {
		chunk := ips[start:min(start+ip4logLookupChunk, len(ips))]
		query := "SELECT ip, mac FROM ip4log WHERE ip IN (?" + strings.Repeat(", ?", len(chunk)-1) + ")"
		args := make([]interface{}, len(chunk))
		for i, ip := range chunk {
			args[i] = ip
		}

		rows, err := dbh.QueryContext(ctx, query, args...)
		if err != nil {
			log.LogErrorf(ctx, "lookupIp4logMacs Database Error: %s", err.Error())
			continue
		}

		for rows.Next() {
			var ip, mac string
			if err := rows.Scan(&ip, &mac); err != nil {
				log.LogErrorf(ctx, "lookupIp4logMacs Scan Error: %s", err.Error())
				break
			}

			macs[ip] = mac
		}

		rows.Close()
	}

	return macs
}
