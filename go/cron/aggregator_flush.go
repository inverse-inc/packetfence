package maint

import (
	"cmp"
	"context"
	"database/sql"
	"math"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
)

// windowStats counts what the aggregator ingested during one flush interval.
type windowStats struct {
	messages int
	flows    int
	// agents holds the distinct exporter addresses seen in the window; they
	// are marked as seen in switch_observability once per flush instead of
	// once per Kafka message on the ingest goroutine.
	agents map[string]struct{}
}

func newWindowStats() windowStats {
	return windowStats{agents: map[string]struct{}{}}
}

func (s *windowStats) noteAgent(addr string) {
	if s.agents == nil {
		s.agents = map[string]struct{}{}
	}
	s.agents[addr] = struct{}{}
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
	a.markSwitchesSeen(ctx, batch.stats.agents)
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

// markSwitchesSeen records the window's exporters in switch_observability.
// MarkSwitchAsSeen keeps its own per-switch cache, so this costs at most one
// statement per switch per minute, and a slow database only delays the flush
// rather than the Kafka consumer.
func (a *Aggregator) markSwitchesSeen(ctx context.Context, agents map[string]struct{}) {
	if a.db == nil {
		return
	}

	for addr := range agents {
		if err := db.MarkSwitchAsSeen(a.db, addr); err != nil {
			log.LogErrorf(ctx, "pfflow aggregator: failed to mark switch %s as seen: %s", addr, err.Error())
		}
	}
}

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
	complete := true
	if len(ipSet) > 0 {
		ips := make([]string, 0, len(ipSet))
		for ip := range ipSet {
			ips = append(ips, ip)
		}

		macs, complete = lookupIp4logMacs(ctx, dbh, ips)
	}

	applyResolvedMacs(events, macs, complete)
	return len(ipSet)
}

// applyResolvedMacs writes the looked-up MACs into the flows. When the lookup
// was complete, an IP absent from macs has no ip4log row and gets the zero
// MAC (the previous per-flow COALESCE); when a chunk query failed, absent IPs
// keep their empty MAC so the flows still become IP-only network events, as
// the previous per-flow lookup did on a database error, instead of being
// dropped by ToNetworkEvent for carrying two zero MACs.
func applyResolvedMacs(events map[EventKey][]PfFlow, macs map[string]string, complete bool) {
	resolve := func(ip string) (string, bool) {
		if mac, ok := macs[ip]; ok {
			return mac, true
		}
		if complete {
			return "00:00:00:00:00:00", true
		}
		return "", false
	}

	for _, flows := range events {
		for i := range flows {
			f := &flows[i]
			if !emptyMac(f.SrcMac) && !emptyMac(f.DstMac) {
				continue
			}

			if emptyMac(f.SrcMac) {
				if mac, ok := resolve(f.SrcIp.String()); ok {
					f.SrcMac = mac
				}
			}

			if emptyMac(f.DstMac) {
				if mac, ok := resolve(f.DstIp.String()); ok {
					f.DstMac = mac
				}
			}
		}
	}
}

// lookupIp4logMacs returns the ip4log MAC of each IP that has one. complete is
// false when at least one chunk query failed or was cut short, in which case
// absent IPs cannot be distinguished from IPs without an ip4log row.
func lookupIp4logMacs(ctx context.Context, dbh *sql.DB, ips []string) (map[string]string, bool) {
	return queryStringPairs(ctx, dbh, "lookupIp4logMacs", "SELECT ip, mac FROM ip4log WHERE ip IN (", ips, ip4logLookupChunk)
}

// queryStringPairs runs sqlPrefix + "?, ?, ..." + ")" for each chunk of keys
// and collects the (key, value) string pairs it returns. Errors are logged
// under name; the boolean is false when any chunk failed or its iteration was
// cut short, so callers can tell "no row" from "unknown".
func queryStringPairs(ctx context.Context, dbh *sql.DB, name, sqlPrefix string, keys []string, chunkSize int) (map[string]string, bool) {
	result := make(map[string]string, len(keys))
	complete := true
	for start := 0; start < len(keys); start += chunkSize {
		chunk := keys[start:min(start+chunkSize, len(keys))]
		query := sqlPrefix + "?" + strings.Repeat(", ?", len(chunk)-1) + ")"
		args := make([]interface{}, len(chunk))
		for i, k := range chunk {
			args[i] = k
		}

		rows, err := dbh.QueryContext(ctx, query, args...)
		if err != nil {
			log.LogErrorf(ctx, "%s Database Error: %s", name, err.Error())
			complete = false
			continue
		}

		for rows.Next() {
			var k, v string
			if err := rows.Scan(&k, &v); err != nil {
				log.LogErrorf(ctx, "%s Scan Error: %s", name, err.Error())
				complete = false
				break
			}

			result[k] = v
		}

		// rows.Next() returns false on a mid-stream failure too (connection
		// reset, killed query); without this the chunk silently comes back
		// truncated.
		if err := rows.Err(); err != nil {
			log.LogErrorf(ctx, "%s Rows Error: %s", name, err.Error())
			complete = false
		}

		rows.Close()
	}

	return result, complete
}
