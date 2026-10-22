package clientapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

type fakeTunnel struct {
	active atomic.Bool
}

func (f *fakeTunnel) IsActive() bool { return f.active.Load() }

// newStubServer returns an httptest server that serves a minimal valid
// multi-domain-config payload and counts hits.
func newStubServer(hits *atomic.Int32) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"realms":{"example.com":{"regex":"","domain":"EXAMPLE"}},"ordered_realms":["example.com"],"domains":{"EXAMPLE":{"ntlm_auth_host":"127.0.0.1","ntlm_auth_port":"4999","use_connector":"0"}}}`))
	}))
}

// waitForHits blocks until `hits` reaches `want` or `timeout` elapses.
// Returns the final count.
func waitForHits(hits *atomic.Int32, want int32, timeout time.Duration) int32 {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if hits.Load() >= want {
			return hits.Load()
		}
		time.Sleep(5 * time.Millisecond)
	}
	return hits.Load()
}

// waitForCache blocks until the cache holds a populated config or `timeout`
// elapses, returning the latest config (nil on timeout). Needed because the
// `hits` counter is bumped server-side when the request arrives, which races
// ahead of the client-side fetch->decode->set that actually fills the cache;
// observing hits>=1 does not guarantee the cache is populated yet.
func waitForCache(c *multiDomainCache, timeout time.Duration) *multiDomainConfig {
	deadline := time.Now().Add(timeout)
	for {
		if cfg, _ := c.get(); cfg != nil {
			return cfg
		}
		if !time.Now().Before(deadline) {
			cfg, _ := c.get()
			return cfg
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func withShortPoll(t *testing.T, interval time.Duration) {
	t.Helper()
	orig := multiDomainTunnelPollInterval
	multiDomainTunnelPollInterval = interval
	t.Cleanup(func() { multiDomainTunnelPollInterval = orig })
}

// TestRefresher_NoFetchWhileTunnelDown verifies that while the tunnel reports
// down the refresher never calls the upstream — no noisy failed fetches.
func TestRefresher_NoFetchWhileTunnelDown(t *testing.T) {
	withShortPoll(t, 20*time.Millisecond)
	t.Setenv("PFCONNECTOR_MULTI_DOMAIN_REFRESH_INTERVAL", "1")

	var hits atomic.Int32
	srv := newStubServer(&hits)
	defer srv.Close()

	cache := newMultiDomainCache(srv.URL)
	tun := &fakeTunnel{} // stays down

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cache.startRefresher(ctx, tun)

	// Give the refresher well more than the poll interval to misbehave.
	time.Sleep(200 * time.Millisecond)

	if got := hits.Load(); got != 0 {
		t.Fatalf("expected 0 fetches while tunnel down, got %d", got)
	}
	if cfg, _ := cache.get(); cfg != nil {
		t.Fatalf("expected empty cache while tunnel down, got %#v", cfg)
	}
}

// TestRefresher_FetchOnTunnelUp verifies the down→up transition triggers an
// immediate fetch, and that the refresh cadence keeps firing while up.
func TestRefresher_FetchOnTunnelUp(t *testing.T) {
	withShortPoll(t, 20*time.Millisecond)
	// Very short "while-up" cadence so we can observe a second refresh.
	t.Setenv("PFCONNECTOR_MULTI_DOMAIN_REFRESH_INTERVAL", "1")

	var hits atomic.Int32
	srv := newStubServer(&hits)
	defer srv.Close()

	cache := newMultiDomainCache(srv.URL)
	tun := &fakeTunnel{}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cache.startRefresher(ctx, tun)

	// Tunnel down for a bit — no fetches should happen.
	time.Sleep(100 * time.Millisecond)
	if got := hits.Load(); got != 0 {
		t.Fatalf("expected 0 fetches before tunnel-up, got %d", got)
	}

	// Bring the tunnel up.
	tun.active.Store(true)

	if got := waitForHits(&hits, 1, 500*time.Millisecond); got < 1 {
		t.Fatalf("expected at least 1 fetch after tunnel-up, got %d", got)
	}

	// Wait for the cache to actually be populated rather than inferring it
	// from the hits counter, which is bumped before the client sets the cache.
	if cfg := waitForCache(cache, 500*time.Millisecond); cfg == nil || cfg.Realms["example.com"].Domain != "EXAMPLE" {
		t.Fatalf("expected cache populated after tunnel-up, got %#v", cfg)
	}

	// With the refresh interval set to 1s and poll at 20ms, we should see a
	// second fetch within ~1.2s.
	if got := waitForHits(&hits, 2, 1500*time.Millisecond); got < 2 {
		t.Fatalf("expected a periodic refresh while tunnel up, got %d fetches", got)
	}
}

// TestRefresher_NilTunnelBehavesAsUp preserves the pre-change refresh-always
// behavior for callers that don't pass a tunnel.
func TestRefresher_NilTunnelBehavesAsUp(t *testing.T) {
	withShortPoll(t, 20*time.Millisecond)
	t.Setenv("PFCONNECTOR_MULTI_DOMAIN_REFRESH_INTERVAL", "1")

	var hits atomic.Int32
	srv := newStubServer(&hits)
	defer srv.Close()

	cache := newMultiDomainCache(srv.URL)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cache.startRefresher(ctx, nil)

	if got := waitForHits(&hits, 1, 500*time.Millisecond); got < 1 {
		t.Fatalf("expected at least 1 fetch with nil tunnel, got %d", got)
	}
}
