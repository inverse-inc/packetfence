package uiplugins

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync/atomic"
	"testing"
	"time"
)

func registrationFor(t *testing.T, id string, server *httptest.Server, path string) Registration {
	host, port, err := net.SplitHostPort(server.Listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	p, _ := strconv.Atoi(port)
	return Registration{ID: id, Scheme: "http", Host: host, Port: p, ManifestPath: path}
}

func TestFetcherPlugins(t *testing.T) {
	var calls int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&calls, 1)
		switch r.URL.Path {
		case "/acme.json":
			w.Write([]byte(valid))
		case "/invalid.json":
			w.Write([]byte(`{"manifestVersion": 1, "id": "invalid"}`))
		case "/slow.json":
			time.Sleep(500 * time.Millisecond)
			w.Write([]byte(valid))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	logged := []string{}
	f := NewFetcher(func(ctx context.Context, msg string) { logged = append(logged, msg) })
	f.Client.Timeout = 200 * time.Millisecond

	registrations := map[string]Registration{
		"acme":    registrationFor(t, "acme", server, "/acme.json"),
		"invalid": registrationFor(t, "invalid", server, "/invalid.json"),
		"missing": registrationFor(t, "missing", server, "/missing.json"),
		"slow":    registrationFor(t, "slow", server, "/slow.json"),
		"down":    {ID: "down", Scheme: "http", Host: "127.0.0.1", Port: 1, ManifestPath: "/m"},
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
	other := registrationFor(t, "other", server, "/acme.json")
	if plugins := f.Plugins(context.Background(), map[string]Registration{"other": other}); len(plugins) != 0 {
		t.Errorf("a manifest of another id was accepted: %+v", plugins)
	}
}
