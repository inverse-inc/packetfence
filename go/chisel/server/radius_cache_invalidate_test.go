package chserver

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

type sendRecorder struct {
	mu    sync.Mutex
	calls []string // "connector mac,mac"
	fail  map[string]bool
}

func (r *sendRecorder) send(connectorID string, macs []string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	joined := ""
	for i, m := range macs {
		if i > 0 {
			joined += ","
		}
		joined += m
	}
	r.calls = append(r.calls, connectorID+" "+joined)
	if r.fail[connectorID] {
		return errors.New("no active tunnel")
	}
	return nil
}

func (r *sendRecorder) snapshot() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]string(nil), r.calls...)
}

func TestNormalizeMacServer(t *testing.T) {
	for in, want := range map[string]string{"AA-BB-CC-DD-EE-01": "aa:bb:cc:dd:ee:01", "aabb.ccdd.ee02": "aa:bb:cc:dd:ee:02", " aa:bb:cc:dd:ee:03 ": "aa:bb:cc:dd:ee:03"} {
		if got, ok := normalizeMac(in); !ok || got != want {
			t.Errorf("%q: %q %v", in, got, ok)
		}
	}
	for _, bad := range []string{"", "aa:bb", "zz:bb:cc:dd:ee:ff", "aa:bb:cc:dd:ee:ff:00"} {
		if _, ok := normalizeMac(bad); ok {
			t.Errorf("%q must be refused", bad)
		}
	}
}

func TestInvalidationBatcherCoalesces(t *testing.T) {
	rec := &sendRecorder{}
	b := newInvalidationBatcher(40*time.Millisecond, 3, rec.send, newPendingInvalidations(time.Minute, 100))
	b.Add("site-a", []string{"aa:bb:cc:dd:ee:02"})
	b.Add("site-a", []string{"aa:bb:cc:dd:ee:01", "aa:bb:cc:dd:ee:02"})
	b.Add("site-b", []string{"aa:bb:cc:dd:ee:01"})
	time.Sleep(100 * time.Millisecond)
	calls := rec.snapshot()
	if len(calls) != 2 || calls[0] != "site-a aa:bb:cc:dd:ee:01,aa:bb:cc:dd:ee:02" && calls[1] != "site-a aa:bb:cc:dd:ee:01,aa:bb:cc:dd:ee:02" {
		t.Fatalf("a burst must become one deduplicated list per connector: %q", calls)
	}
	// a full batch leaves at once, the rest after the delay
	b.Add("site-a", []string{"aa:bb:cc:dd:ee:03", "aa:bb:cc:dd:ee:04", "aa:bb:cc:dd:ee:05", "aa:bb:cc:dd:ee:06"})
	time.Sleep(5 * time.Millisecond)
	if calls := rec.snapshot(); len(calls) != 4 {
		t.Fatalf("a full batch must leave immediately, in chunks: %q", calls)
	}
}

func TestInvalidationPendingAndFlush(t *testing.T) {
	rec := &sendRecorder{fail: map[string]bool{"site-down": true}}
	pending := newPendingInvalidations(time.Minute, 2)
	b := newInvalidationBatcher(10*time.Millisecond, 1000, rec.send, pending)
	b.Add("site-down", []string{"aa:bb:cc:dd:ee:01"})
	time.Sleep(50 * time.Millisecond)
	// undelivered: kept, capped at the max (oldest dropped)
	pending.Remember("site-down", []string{"aa:bb:cc:dd:ee:02", "aa:bb:cc:dd:ee:03"})
	if got := pending.Take("site-down"); len(got) != 2 || got[0] == "aa:bb:cc:dd:ee:01" {
		t.Fatalf("pending must keep the newest %d: %q", 2, got)
	}
	if got := pending.Take("site-down"); len(got) != 0 {
		t.Fatalf("Take must forget: %q", got)
	}
	// expired entries are not replayed
	expired := newPendingInvalidations(-time.Second, 10)
	expired.Remember("site-x", []string{"aa:bb:cc:dd:ee:09"})
	if got := expired.Take("site-x"); len(got) != 0 {
		t.Fatalf("expired pending must be dropped: %q", got)
	}
	// the connector comes back: the pending list is replayed once
	pending.Remember("site-down", []string{"aa:bb:cc:dd:ee:05"})
	rec.fail = map[string]bool{}
	b.FlushPending("site-down")
	calls := rec.snapshot()
	if calls[len(calls)-1] != "site-down aa:bb:cc:dd:ee:05" {
		t.Fatalf("flush must replay the pending list: %q", calls)
	}
	if got := pending.Take("site-down"); len(got) != 0 {
		t.Fatalf("a replayed list must be forgotten: %q", got)
	}
}

func TestHandleRadiusCacheInvalidate(t *testing.T) {
	rec := &sendRecorder{fail: map[string]bool{"site-down": true}}
	saved := radiusCacheInvalidator
	radiusCacheInvalidator = newInvalidationBatcher(10*time.Millisecond, 1000, rec.send, newPendingInvalidations(time.Minute, 100))
	defer func() { radiusCacheInvalidator = saved }()
	s := &Server{}
	do := func(method, body string) (*httptest.ResponseRecorder, map[string]interface{}) {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(method, apiPrefix+"/radius-cache-invalidate", bytes.NewBufferString(body))
		s.handleRadiusCacheInvalidate(rr, req)
		out := map[string]interface{}{}
		_ = json.Unmarshal(rr.Body.Bytes(), &out)
		return rr, out
	}
	if rr, _ := do(http.MethodGet, ""); rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("GET: %d", rr.Code)
	}
	for _, body := range []string{"{not json", `{"macs":[]}`, `{"macs":["nope"]}`} {
		if rr, _ := do(http.MethodPost, body); rr.Code != http.StatusBadRequest {
			t.Fatalf("%s: expected 400, got %d", body, rr.Code)
		}
	}
	// async: no tunnel in this test, every connector goes to the pending list
	rr, out := do(http.MethodPost, `{"connector_ids":["site-a"],"macs":["AA-BB-CC-DD-EE-01"]}`)
	if rr.Code != http.StatusAccepted || len(out["no_tunnel"].([]interface{})) != 1 {
		t.Fatalf("async without tunnel: %d %v", rr.Code, out)
	}
	if got := radiusCacheInvalidator.pending.Take("site-a"); len(got) != 1 || got[0] != "aa:bb:cc:dd:ee:01" {
		t.Fatalf("pending after async without tunnel: %q", got)
	}
	// sync: the sender is called inline, per-connector results
	rr, out = do(http.MethodPost, `{"connector_ids":["site-a","site-down"],"macs":["aa:bb:cc:dd:ee:01","aa:bb:cc:dd:ee:01"],"sync":true}`)
	if rr.Code != http.StatusOK {
		t.Fatalf("sync: %d %s", rr.Code, rr.Body.String())
	}
	results := out["results"].(map[string]interface{})
	if results["site-a"].(map[string]interface{})["devices"] != 1.0 || results["site-down"].(map[string]interface{})["error"] == nil {
		t.Fatalf("sync results: %v", results)
	}
	if got := radiusCacheInvalidator.pending.Take("site-down"); len(got) != 1 {
		t.Fatalf("a failed sync delivery must be kept pending: %q", got)
	}
}
