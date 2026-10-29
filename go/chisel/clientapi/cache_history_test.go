package clientapi

import (
	"net/http"
	"testing"
	"time"
)

func statsAt(n int) ConnectorCacheStats {
	return ConnectorCacheStats{MemAlloc: int64(n), MemSys: int64(2 * n), DBSize: int64(10 * n), DevicesInDB: n, CredentialInDB: n + 1, KeysInRatelimit: n + 2}
}

func TestCacheHistoryRead(t *testing.T) {
	now := time.Date(2026, 10, 28, 15, 0, 5, 0, time.UTC)
	h := newCacheHistory(now.Add(-time.Hour))
	// three samples in the current 10s bucket (15:00:00-15:00:10), one 30s
	// ago, one out of the 5m window
	h.add(now.Add(-6*time.Minute), statsAt(1000))
	h.add(now.Add(-30*time.Second), statsAt(4))
	h.add(now.Add(-4*time.Second), statsAt(1))
	h.add(now.Add(-3*time.Second), statsAt(2))
	h.add(now, statsAt(3))

	out := h.read("5m", now)
	if out.Window != "5m" || out.BucketSeconds != 10 || len(out.Buckets) != 30 {
		t.Fatalf("window %q bucket %d buckets %d", out.Window, out.BucketSeconds, len(out.Buckets))
	}
	last := out.Buckets[29]
	if !last.At.Equal(now.Truncate(10 * time.Second)) {
		t.Errorf("last bucket starts at %s", last.At)
	}
	if last.Samples != 3 || last.ConnectorCacheStats == nil || last.DevicesInDB != 2 || last.MemSys != 4 || last.KeysInRatelimit != 4 {
		t.Errorf("last bucket = %+v %+v", last, last.ConnectorCacheStats)
	}
	// 30s ago: 3 buckets before the last
	prev := out.Buckets[26]
	if prev.Samples != 1 || prev.ConnectorCacheStats == nil || prev.DevicesInDB != 4 {
		t.Errorf("bucket -30s = %+v %+v", prev, prev.ConnectorCacheStats)
	}
	// an empty bucket carries no statistics
	if empty := out.Buckets[0]; empty.Samples != 0 || empty.ConnectorCacheStats != nil {
		t.Errorf("first bucket = %+v %+v", empty, empty.ConnectorCacheStats)
	}
	if out.Buckets[0].At != now.Truncate(10*time.Second).Add(10*time.Second-5*time.Minute) {
		t.Errorf("first bucket starts at %s", out.Buckets[0].At)
	}
	// the 24h window sees the old sample too
	day := h.read("24h", now)
	if len(day.Buckets) != 288 || day.BucketSeconds != 300 {
		t.Fatalf("24h: %d buckets of %ds", len(day.Buckets), day.BucketSeconds)
	}
	total := 0
	for _, b := range day.Buckets {
		total += b.Samples
	}
	if total != 5 {
		t.Errorf("24h holds %d samples, want 5", total)
	}
}

func TestCacheHistoryRetention(t *testing.T) {
	now := time.Now()
	h := newCacheHistory(now)
	h.add(now.Add(-25*time.Hour), statsAt(1))
	h.add(now.Add(-23*time.Hour), statsAt(2))
	h.add(now, statsAt(3))
	if len(h.samples) != 2 || h.samples[0].Stats.DevicesInDB != 2 {
		t.Fatalf("samples kept: %+v", h.samples)
	}
}

func TestCacheHistorySampleAndHandler(t *testing.T) {
	server, fake := newCacheTestServer(t)
	// the fake connector-cache answers canned stats
	saved := connectorCacheStatsURL
	connectorCacheStatsURL = connectorCacheURL + "/manage/stats"
	t.Cleanup(func() { connectorCacheStatsURL = saved })

	h := newCacheHistory(time.Now())
	if !h.sample(time.Now()) {
		t.Fatalf("sample failed, last backend call %q", fake.lastCall())
	}
	fake.status = http.StatusInternalServerError
	if h.sample(time.Now()) {
		t.Fatal("a failed stats call must not add a sample")
	}
	fake.status = 0
	if len(h.samples) != 1 || h.samples[0].Stats.DevicesInDB != 12 {
		t.Fatalf("samples: %+v", h.samples)
	}

	status, out := doJSON(t, "GET", server.URL+"/cache/stats/history?window=bogus", "")
	if status != http.StatusBadRequest {
		t.Fatalf("bogus window: status %d %v", status, out)
	}
	status, out = doJSON(t, "GET", server.URL+"/cache/stats/history?window=15m", "")
	if status != http.StatusOK {
		t.Fatalf("status %d: %v", status, out)
	}
	if out["window"] != "15m" || out["bucket_seconds"] != float64(10) {
		t.Errorf("reply: %v", out)
	}
	buckets, _ := out["buckets"].([]interface{})
	if len(buckets) != 90 {
		t.Errorf("%d buckets, want 90", len(buckets))
	}
}

// The cache-first counters are monotonic in connector-cache: the history
// keeps per-sample increments and sums them per bucket; a counter that went
// backwards (service restarted) counts nothing for that interval.
func TestCacheHistoryCounterIncrements(t *testing.T) {
	now := time.Date(2026, 10, 29, 15, 0, 9, 0, time.UTC)
	h := newCacheHistory(now.Add(-time.Hour))
	counters := func(hits int64) ConnectorCacheStats { return ConnectorCacheStats{CacheFirstHits: hits, Invalidations: hits / 10} }
	// first sample: no previous reading, nothing counted
	h.add(now.Add(-33*time.Second), counters(10))
	h.add(now.Add(-23*time.Second), counters(13))
	h.add(now.Add(-13*time.Second), counters(13))
	h.add(now.Add(-3*time.Second), counters(20))
	h.add(now, counters(2)) // restarted
	out := h.read("5m", now)
	last := out.Buckets[29]
	if last.Samples != 2 || last.CacheFirstHits != 7 || last.Invalidations != 1 {
		t.Fatalf("last bucket: %+v %+v", last, last.ConnectorCacheStats)
	}
	if b := out.Buckets[28]; b.CacheFirstHits != 0 {
		t.Fatalf("unchanged counter: %+v", b.ConnectorCacheStats)
	}
	if b := out.Buckets[27]; b.CacheFirstHits != 3 {
		t.Fatalf("increment: %+v", b.ConnectorCacheStats)
	}
	if b := out.Buckets[26]; b.CacheFirstHits != 0 {
		t.Fatalf("first reading must count nothing: %+v", b.ConnectorCacheStats)
	}
}
