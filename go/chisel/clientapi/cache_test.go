package clientapi

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
)

// fakeConnectorCache records the manage calls it receives and answers with
// canned replies, the way connector-cache does (JSON bodies, plain-text
// errors, PascalCase stats keys).
type fakeConnectorCache struct {
	mu      sync.Mutex
	calls   []string // "METHOD /path body"
	status  int      // forced status for every call (0 = normal)
	message string   // body for a forced error status
}

func (f *fakeConnectorCache) handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.calls = append(f.calls, strings.TrimSpace(r.Method+" "+r.URL.Path+" "+string(body)))
		f.mu.Unlock()
		// chi's AllowContentType only checks requests with a body
		if r.ContentLength != 0 && r.Header.Get("Content-Type") != "application/json" {
			http.Error(w, "unsupported content type", http.StatusUnsupportedMediaType)
			return
		}
		if f.status != 0 {
			w.WriteHeader(f.status)
			w.Write([]byte(f.message))
			return
		}
		switch r.Method + " " + r.URL.Path {
		case "GET /api/v1/manage/stats":
			w.Write([]byte(`{"MemAlloc":1024,"MemSys":4096,"DBSize":65536,"DevicesInDB":12,"CredentialInDB":3,"KeysInRatelimit":7,"CacheFirstHits":40,"CacheFirstMisses":5,"CacheFirstStale":2,"CacheFirstIneligible":1,"Invalidations":9}`))
		case "POST /api/v1/radcache/delete":
			// connector-cache answers 200 with an empty body, whether or not an entry existed
		case "GET /api/v1/manage/config", "PUT /api/v1/manage/config":
			w.Write([]byte(`{"database": {"cache_ram_size": 256, "startup_clean": true}, "server": {"port": 12142}, "app": {"radius_attribute_ttl": 30, "credential_ttl": 30, "radius_attribute_filters": ["control:"], "rate_limit_rate": 6, "rate_limit_reject": false, "rate_limit_key_max_age": 4}}`))
		case "POST /api/v1/manage/optimize-db", "POST /api/v1/manage/clean", "POST /api/v1/manage/restart":
			// connector-cache answers 200 with an empty body
		default:
			http.NotFound(w, r)
		}
	})
}

func (f *fakeConnectorCache) lastCall() string {
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.calls) == 0 {
		return ""
	}
	return f.calls[len(f.calls)-1]
}

// newCacheTestServer serves the /cache routes in front of a fake
// connector-cache and returns both.
func newCacheTestServer(t *testing.T) (*httptest.Server, *fakeConnectorCache) {
	t.Helper()
	fake := &fakeConnectorCache{}
	backend := httptest.NewServer(fake.handler())
	t.Cleanup(backend.Close)

	saved := connectorCacheURL
	connectorCacheURL = backend.URL + "/api/v1"
	t.Cleanup(func() { connectorCacheURL = saved })

	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	api := &API{ctx: ctx, cacheHistory: newCacheHistory(time.Now())}

	router := chi.NewRouter()
	mountCacheRoutes(router, api)
	server := httptest.NewServer(router)
	t.Cleanup(server.Close)
	return server, fake
}

func doJSON(t *testing.T, method, url, body string) (int, map[string]interface{}) {
	t.Helper()
	req, _ := http.NewRequest(method, url, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if ct := res.Header.Get("Content-Type"); ct != "application/json" {
		t.Fatalf("%s %s: content type %q, want application/json", method, url, ct)
	}
	out := map[string]interface{}{}
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		t.Fatalf("%s %s: invalid JSON reply: %v", method, url, err)
	}
	return res.StatusCode, out
}

func TestCacheStats(t *testing.T) {
	server, fake := newCacheTestServer(t)
	status, out := doJSON(t, "GET", server.URL+"/cache/stats", "")
	if status != http.StatusOK {
		t.Fatalf("status %d: %v", status, out)
	}
	if fake.lastCall() != "GET /api/v1/manage/stats" {
		t.Fatalf("unexpected backend call %q", fake.lastCall())
	}
	// snake_case keys for the admin UI, values carried over
	for key, want := range map[string]float64{"mem_alloc": 1024, "mem_sys": 4096, "db_size": 65536, "devices_in_db": 12, "credential_in_db": 3, "keys_in_ratelimit": 7} {
		if out[key] != want {
			t.Errorf("%s = %v, want %v", key, out[key], want)
		}
	}
}

func TestCacheConfigGet(t *testing.T) {
	server, fake := newCacheTestServer(t)
	status, out := doJSON(t, "GET", server.URL+"/cache/config", "")
	if status != http.StatusOK {
		t.Fatalf("status %d: %v", status, out)
	}
	if fake.lastCall() != "GET /api/v1/manage/config" {
		t.Fatalf("unexpected backend call %q", fake.lastCall())
	}
	app, _ := out["app"].(map[string]interface{})
	if app["rate_limit_rate"] != float64(6) {
		t.Fatalf("configuration not relayed: %v", out)
	}
}

func TestCacheConfigUpdate(t *testing.T) {
	server, fake := newCacheTestServer(t)

	t.Run("editable fields are forwarded verbatim", func(t *testing.T) {
		body := `{"to_update":[{"field":"app.rate_limit_rate","value":10},{"field":"app.rate_limit_reject","value":true},{"field":"app.radius_attribute_filters","value":["control:","MS-MPPE"]}]}`
		status, out := doJSON(t, "PUT", server.URL+"/cache/config", body)
		if status != http.StatusOK {
			t.Fatalf("status %d: %v", status, out)
		}
		if got := fake.lastCall(); got != "PUT /api/v1/manage/config "+body {
			t.Fatalf("backend call %q", got)
		}
		if _, ok := out["app"]; !ok {
			t.Fatalf("the new configuration should be returned: %v", out)
		}
	})

	t.Run("non editable fields are refused before reaching the service", func(t *testing.T) {
		before := len(fake.calls)
		for _, body := range []string{
			`{"to_update":[{"field":"server.port","value":1234}]}`,
			`{"to_update":[{"field":"database.path","value":"/tmp/x.db"}]}`,
			`{"to_update":[{"field":"app.rate_limit_rate","value":null}]}`,
			`{"to_update":[]}`,
			`not json`,
		} {
			status, out := doJSON(t, "PUT", server.URL+"/cache/config", body)
			if status != http.StatusBadRequest {
				t.Errorf("%s: status %d, want 400 (%v)", body, status, out)
			}
			if out["message"] == "" {
				t.Errorf("%s: a message is expected", body)
			}
		}
		if len(fake.calls) != before {
			t.Fatalf("connector-cache must not be called for a refused update: %v", fake.calls[before:])
		}
	})

	t.Run("service validation errors are relayed", func(t *testing.T) {
		fake.status, fake.message = http.StatusBadRequest, "cannot set config\nbad value type on field app.rate_limit_rate: expected int, got string"
		defer func() { fake.status, fake.message = 0, "" }()
		status, out := doJSON(t, "PUT", server.URL+"/cache/config", `{"to_update":[{"field":"app.rate_limit_rate","value":"ten"}]}`)
		if status != http.StatusBadRequest {
			t.Fatalf("status %d, want 400", status)
		}
		if msg, _ := out["message"].(string); !strings.Contains(msg, "bad value type on field app.rate_limit_rate") {
			t.Fatalf("service error not relayed: %v", out)
		}
	})
}

func TestCacheActions(t *testing.T) {
	server, fake := newCacheTestServer(t)
	for _, action := range []string{"optimize-db", "clean", "restart"} {
		status, out := doJSON(t, "POST", server.URL+"/cache/"+action, "")
		if status != http.StatusOK {
			t.Fatalf("%s: status %d: %v", action, status, out)
		}
		if fake.lastCall() != "POST /api/v1/manage/"+action {
			t.Fatalf("%s: unexpected backend call %q", action, fake.lastCall())
		}
		if msg, _ := out["message"].(string); msg == "" {
			t.Fatalf("%s: a confirmation message is expected: %v", action, out)
		}
	}
	// A GET on an action is not a route
	res, err := http.Get(server.URL + "/cache/clean")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusMethodNotAllowed {
		t.Fatalf("GET /cache/clean: status %d, want 405", res.StatusCode)
	}
}

func TestCacheServiceDown(t *testing.T) {
	server, fake := newCacheTestServer(t)
	// Point at a closed port
	closed := httptest.NewServer(http.NotFoundHandler())
	closed.Close()
	connectorCacheURL = closed.URL + "/api/v1"

	status, out := doJSON(t, "GET", server.URL+"/cache/stats", "")
	if status != http.StatusBadGateway {
		t.Fatalf("status %d, want 502 (%v)", status, out)
	}
	if len(fake.calls) != 0 {
		t.Fatalf("the fake must not have been reached: %v", fake.calls)
	}

	// An internal error of the service keeps its status and text
	server2, fake2 := newCacheTestServer(t)
	fake2.status, fake2.message = http.StatusInternalServerError, "OptimzeDB: database is locked"
	status, out = doJSON(t, "POST", server2.URL+"/cache/optimize-db", "")
	if status != http.StatusInternalServerError || !strings.Contains(out["message"].(string), "database is locked") {
		t.Fatalf("status %d %v, want 500 with the service message", status, out)
	}
}

func TestCacheStatsCacheFirstCounters(t *testing.T) {
	server, _ := newCacheTestServer(t)
	status, out := doJSON(t, "GET", server.URL+"/cache/stats", "")
	if status != http.StatusOK || out["cache_first_hits"] != 40.0 || out["invalidations"] != 9.0 || out["cache_first_ineligible"] != 1.0 {
		t.Fatalf("stats: %d %v", status, out)
	}
	// a connector-cache older than 0.1.8 has no counters: zeros, not an error
	stats, err := decodeConnectorCacheStats([]byte(`{"MemAlloc":1,"MemSys":2,"DBSize":3,"DevicesInDB":4,"CredentialInDB":5,"KeysInRatelimit":6}`))
	if err != nil || stats.CacheFirstHits != 0 || stats.DevicesInDB != 4 {
		t.Fatalf("old stats: %+v %v", stats, err)
	}
}

func TestCacheConfigUpdateCacheFirst(t *testing.T) {
	server, fake := newCacheTestServer(t)
	status, _ := doJSON(t, "PUT", server.URL+"/cache/config", `{"to_update":[{"field":"app.cache_first","value":true},{"field":"app.cache_first_ttl","value":3600}]}`)
	if status != http.StatusOK {
		t.Fatalf("status %d", status)
	}
	if call := fake.lastCall(); !strings.Contains(call, `"app.cache_first"`) || !strings.Contains(call, `3600`) {
		t.Fatalf("cache-first fields must be forwarded: %s", call)
	}
}

func TestRadiusCacheInvalidate(t *testing.T) {
	fake := &fakeConnectorCache{}
	backend := httptest.NewServer(fake.handler())
	t.Cleanup(backend.Close)
	saved := connectorCacheURL
	connectorCacheURL = backend.URL + "/api/v1"
	t.Cleanup(func() { connectorCacheURL = saved })
	api := &API{ctx: context.Background()}
	router := chi.NewRouter()
	router.Post("/radius/cache/invalidate", radiusCacheInvalidate(api))
	server := httptest.NewServer(router)
	t.Cleanup(server.Close)

	// two devices in NAS formats, one duplicate, one garbage: two deletes, normalised
	status, out := doJSON(t, "POST", server.URL+"/radius/cache/invalidate", `{"macs":["AA-BB-CC-DD-EE-01","aabb.ccdd.ee02","aa:bb:cc:dd:ee:01","not-a-mac"]}`)
	if status != http.StatusOK || out["deleted"] != 2.0 {
		t.Fatalf("invalidate: %d %v", status, out)
	}
	fake.mu.Lock()
	calls := append([]string(nil), fake.calls...)
	fake.mu.Unlock()
	if len(calls) != 2 || calls[0] != `POST /api/v1/radcache/delete {"mac":"aa:bb:cc:dd:ee:01"}` || calls[1] != `POST /api/v1/radcache/delete {"mac":"aa:bb:cc:dd:ee:02"}` {
		t.Fatalf("deletes sent to the cache: %q", calls)
	}
	// bad requests
	for _, body := range []string{`not json`, `{"macs":[]}`, `{"macs":["zz"]}`} {
		if status, _ := doJSON(t, "POST", server.URL+"/radius/cache/invalidate", body); status != http.StatusBadRequest {
			t.Fatalf("%s: expected 400, got %d", body, status)
		}
	}
	// the cache refuses one: reported, still 200
	fake.status, fake.message = http.StatusInternalServerError, "boom"
	status, out = doJSON(t, "POST", server.URL+"/radius/cache/invalidate", `{"macs":["aa:bb:cc:dd:ee:03"]}`)
	if status != http.StatusOK || out["deleted"] != 0.0 || len(out["failed"].([]interface{})) != 1 {
		t.Fatalf("refused delete: %d %v", status, out)
	}
	// the cache is down: 502
	backend.Close()
	status, _ = doJSON(t, "POST", server.URL+"/radius/cache/invalidate", `{"macs":["aa:bb:cc:dd:ee:03"]}`)
	if status != http.StatusBadGateway {
		t.Fatalf("cache down: expected 502, got %d", status)
	}
}
