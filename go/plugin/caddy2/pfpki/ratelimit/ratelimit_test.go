package ratelimit

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	chi "github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func TestClientKey(t *testing.T) {
	for _, c := range []struct {
		name   string
		remote string
		xff    []string
		want   string
	}{
		{"direct client", "192.0.2.10:1234", nil, "192.0.2.10"},
		{"direct client can't forge", "192.0.2.10:1234", []string{"198.51.100.1"}, "192.0.2.10"},
		{"portal haproxy appends", "100.64.0.1:40000", []string{"198.51.100.1, 203.0.113.9", "192.0.2.10"}, "192.0.2.10"},
		{"caddy replaces", "100.64.0.1:40000", []string{"192.0.2.20"}, "192.0.2.20"},
		{"loopback proxy", "127.0.0.1:40000", []string{"192.0.2.10"}, "192.0.2.10"},
		{"proxy without header", "100.64.0.1:40000", nil, "100.64.0.1"},
		{"garbage header", "100.64.0.1:40000", []string{"192.0.2.10, nonsense"}, "100.64.0.1"},
		{"IPv6 per /64", "[2001:db8:1:2:3:4:5:6]:443", nil, "2001:db8:1:2::/64"},
		{"forwarded IPv6", "[::1]:40000", []string{"2001:db8::1"}, "2001:db8::/64"},
	} {
		t.Run(c.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			req.RemoteAddr = c.remote
			for _, v := range c.xff {
				req.Header.Add("X-Forwarded-For", v)
			}
			var got string
			// RealIP runs after KeepPeer, as in pfpki: it rewrites
			// RemoteAddr with the client-controlled first entry.
			KeepPeer(middleware.RealIP(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
				got = ClientKey(r)
			}))).ServeHTTP(httptest.NewRecorder(), req)
			if got != c.want {
				t.Errorf("ClientKey = %q, want %q", got, c.want)
			}
		})
	}
}

func TestLimiter(t *testing.T) {
	now := time.Unix(1000, 0)
	l := New(2, 3)
	l.now = func() time.Time { return now }

	for i := 0; i < 3; i++ {
		if ok, _ := l.Allow("a"); !ok {
			t.Fatalf("request %d of the burst refused", i+1)
		}
	}
	ok, wait := l.Allow("a")
	if ok || wait <= 0 || wait > time.Second {
		t.Fatalf("over the burst: ok=%v wait=%v, want refused with a wait up to 1s", ok, wait)
	}
	if ok, _ := l.Allow("b"); !ok {
		t.Fatalf("another client refused")
	}
	now = now.Add(500 * time.Millisecond)
	if ok, _ := l.Allow("a"); !ok {
		t.Fatalf("refused after a token was refilled")
	}

	// Idle buckets are dropped.
	now = now.Add(time.Hour)
	l.Allow("c")
	if _, ok := l.clients["a"]; ok {
		t.Errorf("idle bucket kept")
	}

	// The number of buckets is bounded.
	l.maxClients = 2
	l.Allow("d")
	l.Allow("e")
	if len(l.clients) > 2 {
		t.Errorf("%d buckets, want at most 2", len(l.clients))
	}
}

func TestLimiterMiddleware(t *testing.T) {
	l := New(0.001, 2)
	h := KeepPeer(l.Middleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {})))
	codes := []int{}
	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodPost, "/", nil)
		req.RemoteAddr = "192.0.2.10:1234"
		res := httptest.NewRecorder()
		h.ServeHTTP(res, req)
		codes = append(codes, res.Code)
		if res.Code == http.StatusTooManyRequests && res.Header().Get("Retry-After") == "" {
			t.Errorf("429 without Retry-After")
		}
	}
	if codes[0] != http.StatusOK || codes[1] != http.StatusOK || codes[2] != http.StatusTooManyRequests {
		t.Errorf("statuses %v, want 200 200 429", codes)
	}
}

func TestLockout(t *testing.T) {
	now := time.Unix(1000, 0)
	l := NewLockout(3, 10*time.Minute, 15*time.Minute)
	l.now = func() time.Time { return now }

	l.Fail("a")
	l.Fail("a")
	if locked, _ := l.Locked("a"); locked {
		t.Fatalf("locked after 2 failures")
	}
	// Failures outside the window don't add up.
	now = now.Add(11 * time.Minute)
	l.Fail("a")
	l.Fail("a")
	if locked, _ := l.Locked("a"); locked {
		t.Fatalf("locked with failures spread over two windows")
	}
	l.Fail("a")
	locked, wait := l.Locked("a")
	if !locked || wait != 15*time.Minute {
		t.Fatalf("Locked = %v, %v, want locked for 15m", locked, wait)
	}
	if locked, _ := l.Locked("b"); locked {
		t.Fatalf("another client locked")
	}
	now = now.Add(15 * time.Minute)
	if locked, _ := l.Locked("a"); locked {
		t.Fatalf("still locked after the lockout")
	}
}

// pfpki mounts the ACME and EST routers through the middleware: their own
// routes and URL parameters still resolve.
func TestLimiterMountedRouter(t *testing.T) {
	sub := chi.NewRouter()
	sub.Get("/{profile}/directory", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(chi.URLParam(r, "profile")))
	})
	r := chi.NewRouter()
	r.Use(KeepPeer)
	r.Mount("/api/v1/pki/acme", New(1, 1).Middleware(sub))

	res := httptest.NewRecorder()
	r.ServeHTTP(res, httptest.NewRequest(http.MethodGet, "/api/v1/pki/acme/prof/directory", nil))
	if res.Code != http.StatusOK || res.Body.String() != "prof" {
		t.Fatalf("status %d body %q, want 200 prof", res.Code, res.Body.String())
	}
	res = httptest.NewRecorder()
	r.ServeHTTP(res, httptest.NewRequest(http.MethodGet, "/api/v1/pki/acme/prof/directory", nil))
	if res.Code != http.StatusTooManyRequests {
		t.Fatalf("second request: status %d, want 429", res.Code)
	}
}
