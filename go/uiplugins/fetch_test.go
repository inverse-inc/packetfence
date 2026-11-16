package uiplugins

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func registrationFor(t *testing.T, name string, server *httptest.Server) Registration {
	host, port, err := net.SplitHostPort(server.Listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	p, _ := strconv.Atoi(port)
	return Registration{Name: name, Host: host, Port: p}
}

// a plugin service answering its manifest with handler, counting the calls
func pluginServer(t *testing.T, calls *int32, handler func(w http.ResponseWriter)) *httptest.Server {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(calls, 1)
		if r.URL.Path != ManifestPath {
			http.NotFound(w, r)
			return
		}
		handler(w)
	}))
	t.Cleanup(server.Close)
	return server
}

func TestFetcherPlugins(t *testing.T) {
	var calls int32
	acme := pluginServer(t, &calls, func(w http.ResponseWriter) { w.Write([]byte(valid)) })
	invalid := pluginServer(t, &calls, func(w http.ResponseWriter) { w.Write([]byte(`{"manifestVersion": 1, "id": "invalid"}`)) })
	missing := pluginServer(t, &calls, func(w http.ResponseWriter) { w.WriteHeader(http.StatusNotFound) })
	slow := pluginServer(t, &calls, func(w http.ResponseWriter) {
		time.Sleep(500 * time.Millisecond)
		w.Write([]byte(valid))
	})

	var lock sync.Mutex
	logged := []string{}
	f := NewFetcher(func(ctx context.Context, msg string) {
		lock.Lock()
		defer lock.Unlock()
		logged = append(logged, msg)
	})
	f.Client.Timeout = 200 * time.Millisecond

	registrations := map[string]Registration{
		"acme":    registrationFor(t, "acme", acme),
		"invalid": registrationFor(t, "invalid", invalid),
		"missing": registrationFor(t, "missing", missing),
		"slow":    registrationFor(t, "slow", slow),
		"down":    {Name: "down", Host: "127.0.0.1", Port: 1},
	}
	plugins := f.Plugins(context.Background(), registrations)
	if len(plugins) != 1 || plugins[0].ID != "acme" || plugins[0].Manifest.Title["en"] != "Acme" {
		t.Fatalf("expected only acme, got %+v", plugins)
	}
	if len(logged) != 4 {
		t.Errorf("expected 4 plugins left out and logged, got %d: %v", len(logged), logged)
	}

	// cached: no new request for the valid plugin
	before := atomic.LoadInt32(&calls)
	f.Plugins(context.Background(), map[string]Registration{"acme": registrations["acme"]})
	if atomic.LoadInt32(&calls) != before {
		t.Error("the manifest was fetched again within the TTL")
	}

	// a manifest whose id is not the registered one
	other := registrationFor(t, "other", acme)
	if plugins := f.Plugins(context.Background(), map[string]Registration{"other": other}); len(plugins) != 0 {
		t.Errorf("a manifest of another id was accepted: %+v", plugins)
	}
}

// after the first fetch, an expired result is answered at once and refreshed
// in the background: a dead plugin does not slow down the UI loads
func TestFetcherRefreshInBackground(t *testing.T) {
	var up atomic.Bool
	up.Store(true)
	var calls int32
	server := pluginServer(t, &calls, func(w http.ResponseWriter) {
		if !up.Load() {
			time.Sleep(300 * time.Millisecond) // a plugin that does not answer
		}
		w.Write([]byte(valid))
	})
	f := NewFetcher(nil)
	f.Client.Timeout = 200 * time.Millisecond
	f.TTL = 50 * time.Millisecond // also the TTL of a failure
	regs := map[string]Registration{"acme": registrationFor(t, "acme", server)}

	if len(f.Plugins(context.Background(), regs)) != 1 {
		t.Fatal("expected acme")
	}
	up.Store(false)
	time.Sleep(60 * time.Millisecond) // expired

	start := time.Now()
	if len(f.Plugins(context.Background(), regs)) != 1 {
		t.Error("the last result must be answered while refreshing")
	}
	if d := time.Since(start); d > 100*time.Millisecond {
		t.Errorf("an expired result waited for the refresh: %s", d)
	}
	// the refreshes time out: the last good manifest is kept for
	// maxRefreshFailures-1 failures, then the plugin is left out
	for failure := 1; failure <= maxRefreshFailures; failure++ {
		time.Sleep(300 * time.Millisecond) // the refresh times out, its error expires (TTL)
		start = time.Now()
		plugins := f.Plugins(context.Background(), regs)
		if d := time.Since(start); d > 100*time.Millisecond {
			t.Errorf("the failed refresh slowed the answer: %s", d)
		}
		if failure < maxRefreshFailures && len(plugins) != 1 {
			t.Errorf("after %d failed refresh(es) the plugin must still be listed", failure)
		}
		if failure == maxRefreshFailures && len(plugins) != 0 {
			t.Errorf("after %d failed refreshes the plugin is still listed: %+v", failure, plugins)
		}
	}
	// the first fetch and the failed refreshes, the last Plugins call may
	// have started one more
	if c := atomic.LoadInt32(&calls); c < 1+maxRefreshFailures || c > 2+maxRefreshFailures {
		t.Errorf("expected %d or %d fetches (first, the refreshes), got %d", 1+maxRefreshFailures, 2+maxRefreshFailures, c)
	}

	// a deregistered plugin is forgotten
	f.Plugins(context.Background(), map[string]Registration{})
	f.lock.Lock()
	n := len(f.cache)
	f.lock.Unlock()
	if n != 0 {
		t.Errorf("%d cache entries left for deregistered plugins", n)
	}
}

// a manifest fetch does not follow redirects: the API cannot be sent to
// another address than the registered one
func TestFetcherRedirect(t *testing.T) {
	var calls, targetCalls int32
	target := pluginServer(t, &targetCalls, func(w http.ResponseWriter) { w.Write([]byte(valid)) })
	redirect := pluginServer(t, &calls, func(w http.ResponseWriter) {
		w.Header().Set("Location", target.URL+ManifestPath)
		w.WriteHeader(http.StatusFound)
	})
	f := NewFetcher(nil)
	if plugins := f.Plugins(context.Background(), map[string]Registration{"acme": registrationFor(t, "acme", redirect)}); len(plugins) != 0 {
		t.Errorf("a redirected manifest was accepted: %+v", plugins)
	}
	if atomic.LoadInt32(&targetCalls) != 0 {
		t.Error("the redirect was followed")
	}
}

// the grace of a working plugin ends refreshGrace after its last success,
// whatever the number of failures
func TestFetcherRefreshGrace(t *testing.T) {
	f := NewFetcher(nil)
	r := Registration{Name: "acme", Host: "127.0.0.1", Port: 1}
	key := cacheKey(r)
	m := &Manifest{ID: "acme"}
	f.store(key, r, m, nil)
	f.store(key, r, nil, context.DeadlineExceeded)
	if got, _ := f.get(context.Background(), r); got != m {
		t.Fatal("the last good manifest must be kept after one failure")
	}
	f.lock.Lock()
	e := f.cache[key]
	e.lastSuccess = time.Now().Add(-refreshGrace)
	f.cache[key] = e
	f.lock.Unlock()
	f.store(key, r, nil, context.DeadlineExceeded)
	f.lock.Lock()
	e = f.cache[key]
	f.lock.Unlock()
	if e.manifest != nil || e.err == nil {
		t.Errorf("the manifest must be dropped after the grace period: %+v", e)
	}
}

// concurrent first requests share one fetch, and an admin request canceled
// during the first fetch does not cache the cancellation
func TestFetcherFirstFetch(t *testing.T) {
	var calls int32
	release := make(chan struct{})
	server := pluginServer(t, &calls, func(w http.ResponseWriter) {
		<-release
		w.Write([]byte(valid))
	})
	f := NewFetcher(nil)
	r := registrationFor(t, "acme", server)

	// a request canceled while the first fetch runs
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() {
		_, err := f.get(ctx, r)
		done <- err
	}()
	time.Sleep(50 * time.Millisecond)
	cancel()
	if err := <-done; err != context.Canceled {
		t.Fatalf("expected the request to end with context.Canceled, got %v", err)
	}

	// concurrent requests wait for the same fetch
	var wg sync.WaitGroup
	results := make(chan *Manifest, 10)
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			m, _ := f.get(context.Background(), r)
			results <- m
		}()
	}
	time.Sleep(50 * time.Millisecond)
	close(release)
	wg.Wait()
	close(results)
	for m := range results {
		if m == nil {
			t.Error("a concurrent request got no manifest")
		}
	}
	if c := atomic.LoadInt32(&calls); c != 1 {
		t.Errorf("expected 1 manifest fetch, got %d", c)
	}
	if m, err := f.get(context.Background(), r); m == nil || err != nil {
		t.Errorf("the fetch of the canceled request must be cached: %v %v", m, err)
	}
}
