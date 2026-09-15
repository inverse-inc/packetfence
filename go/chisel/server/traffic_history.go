package chserver

import (
	"context"
	"encoding/json"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

// Traffic history: the tunnel counters (tunnel/stats.go) are cumulative, so
// the admin UI can only derive a rate from two samples taken while its page
// is open. This keeps a short history on the server instead: every
// trafficSampleInterval the counters of every active tunnel this pod holds
// are recorded, per connector, for trafficHistoryRetention. The
// traffic-history endpoint turns them into rate series (bytes per second,
// overall and per destination) for the charts of the topology view.
//
// Scope: in memory, per pod. A pod restart, or a tunnel reconnecting to
// another pod, starts the connector's series over; a counter that goes
// backwards (new tunnel) is read as "bytes since the new tunnel started".

const (
	trafficSampleInterval   = 5 * time.Second
	trafficHistoryRetention = time.Hour
	trafficHistoryCapacity  = int(trafficHistoryRetention / trafficSampleInterval)
)

type trafficSample struct {
	at       time.Time
	bytesIn  int64
	bytesOut int64
	// services: destination key (reverse ones prefixed "<-") -> {in, out}
	services map[string][2]int64
}

type trafficHistory struct {
	mu          sync.Mutex
	byConnector map[string][]trafficSample
}

var trafficHist = &trafficHistory{byConnector: map[string][]trafficSample{}}

// record appends one sample for a connector, dropping the oldest past the
// capacity.
func (h *trafficHistory) record(connectorID string, at time.Time, st tunnel.StatsSnapshot) {
	sample := trafficSample{at: at, bytesIn: st.BytesIn, bytesOut: st.BytesOut, services: make(map[string][2]int64, len(st.Services))}
	for _, s := range st.Services {
		key := s.Destination
		if s.Reverse {
			key = "<-" + key
		}
		sample.services[key] = [2]int64{s.BytesIn, s.BytesOut}
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	samples := append(h.byConnector[connectorID], sample)
	if len(samples) > trafficHistoryCapacity {
		samples = samples[len(samples)-trafficHistoryCapacity:]
	}
	h.byConnector[connectorID] = samples
}

// sampleAll records every active tunnel of this pod and forgets connectors
// that stopped being sampled for the whole retention.
func (h *trafficHistory) sampleAll(now time.Time) {
	activeTunnels.Range(func(k, v any) bool {
		id, _ := k.(string)
		tun, ok := v.(*tunnel.Tunnel)
		if id == "" || !ok || !tun.IsActive() {
			return true
		}
		h.record(id, now, tun.Stats())
		return true
	})
	h.mu.Lock()
	defer h.mu.Unlock()
	for id, samples := range h.byConnector {
		if len(samples) == 0 || now.Sub(samples[len(samples)-1].at) > trafficHistoryRetention {
			delete(h.byConnector, id)
		}
	}
}

// run samples until ctx is done.
func (h *trafficHistory) run(ctx context.Context) {
	ticker := time.NewTicker(trafficSampleInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			h.sampleAll(now)
		}
	}
}

// TrafficSeries is the reply of /traffic-history: aligned columns of unix
// timestamps and rates in bytes per second, overall and per destination.
type TrafficSeries struct {
	ConnectorID     string                    `json:"connector_id"`
	IntervalSeconds int                       `json:"interval_s"`
	T               []int64                   `json:"t"`
	In              []float64                 `json:"in"`
	Out             []float64                 `json:"out"`
	Services        map[string]*ServiceSeries `json:"services"`
}

// ServiceSeries is one destination's rates, aligned on TrafficSeries.T.
type ServiceSeries struct {
	Reverse bool      `json:"reverse,omitempty"`
	In      []float64 `json:"in"`
	Out     []float64 `json:"out"`
}

// delta is the bytes carried between two cumulative readings: a reading
// lower than the previous one means the tunnel was replaced and the new
// counter started at zero, so the reading itself is the best estimate.
func delta(cur, prev int64) int64 {
	if cur < prev {
		return cur
	}
	return cur - prev
}

// series builds the rates of one connector over the last `since`, nil when
// there are not two samples in that window.
func (h *trafficHistory) series(connectorID string, since time.Duration, now time.Time) *TrafficSeries {
	h.mu.Lock()
	samples := append([]trafficSample(nil), h.byConnector[connectorID]...)
	h.mu.Unlock()
	cutoff := now.Add(-since)
	// Keep one sample before the cutoff so the first point has a rate.
	start := 0
	for i := range samples {
		if samples[i].at.After(cutoff) {
			break
		}
		start = i
	}
	samples = samples[start:]
	if len(samples) < 2 {
		return nil
	}
	out := &TrafficSeries{ConnectorID: connectorID, IntervalSeconds: int(trafficSampleInterval / time.Second), Services: map[string]*ServiceSeries{}}
	keys := map[string]bool{}
	for _, s := range samples {
		for k := range s.services {
			keys[k] = true
		}
	}
	sorted := make([]string, 0, len(keys))
	for k := range keys {
		sorted = append(sorted, k)
	}
	sort.Strings(sorted)
	n := len(samples) - 1
	for _, k := range sorted {
		out.Services[strings.TrimPrefix(k, "<-")] = &ServiceSeries{Reverse: strings.HasPrefix(k, "<-"), In: make([]float64, 0, n), Out: make([]float64, 0, n)}
	}
	for i := 1; i < len(samples); i++ {
		prev, cur := samples[i-1], samples[i]
		dt := cur.at.Sub(prev.at).Seconds()
		if dt <= 0 {
			continue
		}
		out.T = append(out.T, cur.at.Unix())
		out.In = append(out.In, float64(delta(cur.bytesIn, prev.bytesIn))/dt)
		out.Out = append(out.Out, float64(delta(cur.bytesOut, prev.bytesOut))/dt)
		for _, k := range sorted {
			c := cur.services[k]
			p := prev.services[k]
			ss := out.Services[strings.TrimPrefix(k, "<-")]
			ss.In = append(ss.In, float64(delta(c[0], p[0]))/dt)
			ss.Out = append(ss.Out, float64(delta(c[1], p[1]))/dt)
		}
	}
	return out
}

// handleTrafficHistory is GET /api/v1/pfconnector/traffic-history?connector-id=<id>&since=<seconds>.
func (s *Server) handleTrafficHistory(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	connectorID := req.URL.Query().Get("connector-id")
	if connectorID == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: "Missing connector-id query parameter"})
		return
	}
	since := trafficHistoryRetention
	if v := req.URL.Query().Get("since"); v != "" {
		secs, err := strconv.Atoi(v)
		if err != nil || secs <= 0 {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: "Invalid since (seconds)"})
			return
		}
		if d := time.Duration(secs) * time.Second; d < since {
			since = d
		}
	}
	series := trafficHist.series(connectorID, since, time.Now())
	if series == nil {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusNotFound, Message: "No traffic history for this connector on this server"})
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(series)
}
