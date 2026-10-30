package chserver

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

type fireRecorder struct {
	mu  sync.Mutex
	ids []string
}

func (r *fireRecorder) fire(id string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.ids = append(r.ids, id)
}

func (r *fireRecorder) count(id string) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	n := 0
	for _, got := range r.ids {
		if got == id {
			n++
		}
	}
	return n
}

func TestRefreshDebouncerCoalescesABurst(t *testing.T) {
	rec := &fireRecorder{}
	d := newRefreshDebouncer(40*time.Millisecond, rec.fire)
	for i := 0; i < 5; i++ {
		d.Request("a")
		d.Request("b")
		time.Sleep(5 * time.Millisecond)
	}
	time.Sleep(100 * time.Millisecond)
	if rec.count("a") != 1 || rec.count("b") != 1 {
		t.Fatalf("a burst must fire once per connector, got %v", rec.ids)
	}
	// a request after the quiet period fires again
	d.Request("a")
	time.Sleep(80 * time.Millisecond)
	if rec.count("a") != 2 {
		t.Fatalf("a later request must fire again, got %v", rec.ids)
	}
	d.mu.Lock()
	pending := len(d.timers)
	d.mu.Unlock()
	if pending != 0 {
		t.Fatalf("fired timers must be forgotten, %d left", pending)
	}
}

func TestHandleRefreshRadiusNas(t *testing.T) {
	rec := &fireRecorder{}
	saved := radiusNasRefresher
	radiusNasRefresher = newRefreshDebouncer(20*time.Millisecond, rec.fire)
	defer func() { radiusNasRefresher = saved }()
	s := &Server{}

	do := func(method, body string) *httptest.ResponseRecorder {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(method, apiPrefix+"/refresh-radius-nas", bytes.NewBufferString(body))
		s.handleRefreshRadiusNas(rr, req)
		return rr
	}
	if rr := do(http.MethodGet, ""); rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("GET: %d", rr.Code)
	}
	if rr := do(http.MethodPost, "{not json"); rr.Code != http.StatusBadRequest {
		t.Fatalf("bad JSON: %d", rr.Code)
	}
	for i := 0; i < 3; i++ {
		if rr := do(http.MethodPost, `{"connector_id":"conn-1"}`); rr.Code != http.StatusAccepted {
			t.Fatalf("POST: %d %s", rr.Code, rr.Body.String())
		}
	}
	// no tunnel in this test: an empty body targets nobody, and still answers 202
	if rr := do(http.MethodPost, ""); rr.Code != http.StatusAccepted || !bytes.Contains(rr.Body.Bytes(), []byte(`"connectors":[]`)) {
		t.Fatalf("empty body: %d %s", rr.Code, rr.Body.String())
	}
	time.Sleep(60 * time.Millisecond)
	if rec.count("conn-1") != 1 {
		t.Fatalf("three requests must become one refresh, got %v", rec.ids)
	}
}
