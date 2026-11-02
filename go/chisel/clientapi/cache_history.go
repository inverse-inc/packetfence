package clientapi

import (
	"context"
	"net/http"
	"sort"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// History of the connector-cache statistics, for the charts of the admin
// UI's RADIUS Cache tab.
//
// The connector-remote samples connector-cache's /manage/stats every
// cacheHistorySampleInterval and keeps the samples of the last
// cacheHistoryRetention in memory; a sample the service did not answer is a
// gap. GET /api/v1/cache/stats/history?window=5m|15m|1h|24h returns the
// window as a fixed grid of buckets ending now (cacheHistoryWindows), each
// the mean of its samples, or without values when it has none. Like the
// tunnel traffic history of the pfconnector servers, the history starts over
// when the connector-remote restarts.

const (
	cacheHistorySampleInterval = 10 * time.Second
	cacheHistoryRetention      = 24 * time.Hour
)

// cacheHistoryWindows are the windows the admin UI asks for: their length
// and the bucket the samples are averaged in (30 to 288 points).
var cacheHistoryWindows = map[string]struct{ Length, Bucket time.Duration }{
	"5m":  {5 * time.Minute, 10 * time.Second},
	"15m": {15 * time.Minute, 10 * time.Second},
	"1h":  {time.Hour, 20 * time.Second},
	"24h": {24 * time.Hour, 5 * time.Minute},
}

const cacheHistoryDefaultWindow = "1h"

// cacheSample is one reading of the statistics.
type cacheSample struct {
	At    time.Time
	Stats ConnectorCacheStats
}

// cacheHistory is the in-memory ring of samples.
type cacheHistory struct {
	mu      sync.Mutex
	since   time.Time // when the sampler started: the history has no data before
	samples []cacheSample
}

func newCacheHistory(since time.Time) *cacheHistory {
	return &cacheHistory{since: since}
}

// add records a sample taken at the given time and drops the ones older
// than the retention. Samples are expected in chronological order.
func (h *cacheHistory) add(at time.Time, stats ConnectorCacheStats) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.samples = append(h.samples, cacheSample{At: at, Stats: stats})
	cutoff := at.Add(-cacheHistoryRetention)
	keep := sort.Search(len(h.samples), func(i int) bool { return !h.samples[i].At.Before(cutoff) })
	if keep > 0 {
		// reallocate so the dropped head does not pin the backing array
		h.samples = append([]cacheSample(nil), h.samples[keep:]...)
	}
}

// sample takes one reading from connector-cache; false when the service did
// not answer (the gap is left in the history).
func (h *cacheHistory) sample(at time.Time) bool {
	stats := connectorCacheStats()
	if stats == nil {
		return false
	}
	h.add(at, *stats)
	return true
}

// startSampler samples connector-cache until ctx is done.
func (h *cacheHistory) startSampler(ctx context.Context) {
	go func() {
		ticker := time.NewTicker(cacheHistorySampleInterval)
		defer ticker.Stop()
		h.sample(time.Now())
		for {
			select {
			case <-ctx.Done():
				return
			case now := <-ticker.C:
				h.sample(now)
			}
		}
	}()
}

// CacheHistoryBucket is one point of the charts: the mean of the samples of
// a bucket, without the statistics when it has no sample.
type CacheHistoryBucket struct {
	At      time.Time `json:"at"` // start of the bucket
	Samples int       `json:"samples"`
	*ConnectorCacheStats
}

// CacheHistory is the reply of GET /api/v1/cache/stats/history.
type CacheHistory struct {
	Window        string               `json:"window"`
	BucketSeconds int                  `json:"bucket_seconds"`
	Since         time.Time            `json:"since"`
	GeneratedAt   time.Time            `json:"generated_at"`
	Buckets       []CacheHistoryBucket `json:"buckets"`
}

// read returns the history of the window (a key of cacheHistoryWindows) as
// a grid of buckets, the last one holding now.
func (h *cacheHistory) read(window string, now time.Time) *CacheHistory {
	w := cacheHistoryWindows[window]
	end := now.Truncate(w.Bucket).Add(w.Bucket)
	start := end.Add(-w.Length)
	count := int(w.Length / w.Bucket)

	type acc struct {
		n                                                   int
		memAlloc, memSys, dbSize, devices, creds, ratelimit float64
	}
	accs := make([]acc, count)

	h.mu.Lock()
	first := sort.Search(len(h.samples), func(i int) bool { return !h.samples[i].At.Before(start) })
	for _, s := range h.samples[first:] {
		i := int(s.At.Sub(start) / w.Bucket)
		if i < 0 || i >= count {
			continue
		}
		a := &accs[i]
		a.n++
		a.memAlloc += float64(s.Stats.MemAlloc)
		a.memSys += float64(s.Stats.MemSys)
		a.dbSize += float64(s.Stats.DBSize)
		a.devices += float64(s.Stats.DevicesInDB)
		a.creds += float64(s.Stats.CredentialInDB)
		a.ratelimit += float64(s.Stats.KeysInRatelimit)
	}
	since := h.since
	h.mu.Unlock()

	out := &CacheHistory{
		Window:        window,
		BucketSeconds: int(w.Bucket / time.Second),
		Since:         since,
		GeneratedAt:   now,
		Buckets:       make([]CacheHistoryBucket, count),
	}
	for i := range accs {
		a := accs[i]
		b := CacheHistoryBucket{At: start.Add(time.Duration(i) * w.Bucket), Samples: a.n}
		if a.n > 0 {
			n := float64(a.n)
			b.ConnectorCacheStats = &ConnectorCacheStats{
				MemAlloc:        int64(a.memAlloc/n + 0.5),
				MemSys:          int64(a.memSys/n + 0.5),
				DBSize:          int64(a.dbSize/n + 0.5),
				DevicesInDB:     int(a.devices/n + 0.5),
				CredentialInDB:  int(a.creds/n + 0.5),
				KeysInRatelimit: int(a.ratelimit/n + 0.5),
			}
		}
		out.Buckets[i] = b
	}
	return out
}

// cacheStatsHistory is GET /api/v1/cache/stats/history?window=5m|15m|1h|24h.
func cacheStatsHistory(api *API) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		window := r.URL.Query().Get("window")
		if window == "" {
			window = cacheHistoryDefaultWindow
		}
		if _, ok := cacheHistoryWindows[window]; !ok {
			writeMessage(w, http.StatusBadRequest, "window must be 5m, 15m, 1h or 24h")
			return
		}
		history := api.cacheHistory
		if history == nil {
			// a sampler is always started by NewApi; stay safe for the tests
			log.LoggerWContext(api.ctx).Warn("connector-cache history requested but no sampler is running")
			history = newCacheHistory(time.Now())
		}
		writeJSON(w, http.StatusOK, history.read(window, time.Now()))
	}
}
