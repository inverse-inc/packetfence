// Package ratelimit limits the requests pfpki accepts per client on its
// unauthenticated, device-facing endpoints (ACME, EST): each of them can
// write to the database, so a single source must not be able to flood it.
//
// # Client address
//
// pfpki only runs behind reverse proxies, which connect from the host or
// the container network:
//
//   - Devices reach /.well-known/est, /api/v1/pki/acme, SCEP and OCSP on
//     the captive portal (haproxy-portal, backend pki). haproxy's
//     "option forwardfor" appends the address of the client it saw to
//     X-Forwarded-For, after whatever the client sent itself.
//   - /api/v1/pki/* on the web admin port goes through haproxy-admin
//     (1443, "option forwardfor") and the api-frontend Caddy
//     (reverse_proxy). Caddy doesn't trust haproxy-admin, so it replaces
//     X-Forwarded-For with its own peer: the haproxy-admin address. All
//     the clients of that path share one key.
//
// The first X-Forwarded-For entry, which chi's middleware.RealIP puts in
// RemoteAddr, is whatever the client sent. The key is therefore the last
// entry, added by the proxy in front of pfpki, and only when the direct
// peer is one of these proxies (loopback or the container network);
// otherwise the direct peer itself. KeepPeer must run before RealIP so
// the direct peer is still known.
package ratelimit

import (
	"context"
	"math"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

type peerKey struct{}

// KeepPeer records the address of the direct peer of the request before
// a middleware such as chi's RealIP rewrites RemoteAddr.
func KeepPeer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), peerKey{}, r.RemoteAddr)))
	})
}

// trustedProxies are the networks the reverse proxies in front of pfpki
// connect from: loopback and the container network (containers/daemon.json).
var trustedProxies = mustCIDRs("127.0.0.0/8", "::1/128", "100.64.0.0/10")

func mustCIDRs(cidrs ...string) []*net.IPNet {
	var nets []*net.IPNet
	for _, c := range cidrs {
		_, n, err := net.ParseCIDR(c)
		if err != nil {
			panic(err)
		}
		nets = append(nets, n)
	}
	return nets
}

func trusted(ip net.IP) bool {
	for _, n := range trustedProxies {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

// ClientKey returns the address the limits apply to (see the package
// documentation). IPv6 addresses are reduced to their /64, which a single
// client usually holds whole.
func ClientKey(r *http.Request) string {
	peer, _ := r.Context().Value(peerKey{}).(string)
	if peer == "" {
		peer = r.RemoteAddr
	}
	host, _, err := net.SplitHostPort(peer)
	if err != nil {
		host = peer
	}
	ip := net.ParseIP(host)
	if ip == nil {
		return host
	}
	if trusted(ip) {
		if values := r.Header.Values("X-Forwarded-For"); len(values) > 0 {
			entries := strings.Split(values[len(values)-1], ",")
			if fwd := net.ParseIP(strings.TrimSpace(entries[len(entries)-1])); fwd != nil {
				ip = fwd
			}
		}
	}
	if ip.To4() == nil {
		return ip.Mask(net.CIDRMask(64, 128)).String() + "/64"
	}
	return ip.String()
}

// sweepEvery is how often the idle entries are dropped.
const sweepEvery = time.Minute

// Limiter is a token bucket per client key. A bucket left idle long
// enough to be full again is dropped, so the memory used follows the
// number of active clients.
type Limiter struct {
	limit      rate.Limit
	burst      int
	idle       time.Duration
	maxClients int

	mu        sync.Mutex
	clients   map[string]*bucket
	lastSweep time.Time
	now       func() time.Time
}

type bucket struct {
	lim  *rate.Limiter
	seen time.Time
}

// New returns a limiter allowing perSecond requests per second and per
// client, with bursts of burst requests.
func New(perSecond float64, burst int) *Limiter {
	idle := time.Duration(float64(burst)/perSecond*float64(time.Second)) + time.Second
	return &Limiter{
		limit:      rate.Limit(perSecond),
		burst:      burst,
		idle:       idle,
		maxClients: 100000,
		clients:    map[string]*bucket{},
		now:        time.Now,
	}
}

// Allow takes a token for key. When none is left, it returns false and
// how long the client has to wait.
func (l *Limiter) Allow(key string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	l.sweep(now)
	b, ok := l.clients[key]
	if !ok {
		if len(l.clients) >= l.maxClients {
			// Every bucket is active: start over rather than grow
			// without bound.
			l.clients = map[string]*bucket{}
		}
		b = &bucket{lim: rate.NewLimiter(l.limit, l.burst)}
		l.clients[key] = b
	}
	b.seen = now
	res := b.lim.ReserveN(now, 1)
	if delay := res.DelayFrom(now); delay > 0 {
		res.CancelAt(now)
		return false, delay
	}
	return true, 0
}

// sweep drops the buckets idle long enough to be full; mu must be held.
func (l *Limiter) sweep(now time.Time) {
	if now.Sub(l.lastSweep) < sweepEvery {
		return
	}
	l.lastSweep = now
	for key, b := range l.clients {
		if now.Sub(b.seen) > l.idle {
			delete(l.clients, key)
		}
	}
}

// Middleware answers 429 Too Many Requests, with Retry-After, to the
// clients over their limit.
func (l *Limiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if ok, wait := l.Allow(ClientKey(r)); !ok {
			TooManyRequests(w, wait)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// TooManyRequests answers 429 with a Retry-After of wait, in whole seconds.
func TooManyRequests(w http.ResponseWriter, wait time.Duration) {
	w.Header().Set("Retry-After", strconv.Itoa(int(math.Ceil(wait.Seconds()))))
	http.Error(w, "too many requests", http.StatusTooManyRequests)
}

// Lockout locks a client out after too many failures (e.g. wrong
// passwords) within a window.
type Lockout struct {
	failures   int
	window     time.Duration
	lockFor    time.Duration
	maxClients int

	mu        sync.Mutex
	clients   map[string]*failures
	lastSweep time.Time
	now       func() time.Time
}

type failures struct {
	count       int
	since       time.Time
	lockedUntil time.Time
}

// NewLockout locks a client out for lockFor after maxFailures failures
// within window.
func NewLockout(maxFailures int, window, lockFor time.Duration) *Lockout {
	return &Lockout{
		failures:   maxFailures,
		window:     window,
		lockFor:    lockFor,
		maxClients: 100000,
		clients:    map[string]*failures{},
		now:        time.Now,
	}
}

// Locked tells whether key is locked out, and for how long.
func (l *Lockout) Locked(key string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	l.sweep(now)
	if f, ok := l.clients[key]; ok && now.Before(f.lockedUntil) {
		return true, f.lockedUntil.Sub(now)
	}
	return false, 0
}

// Fail records a failure of key. Successes don't clear the failures: a
// shared address can't be used to hide a guessing attempt among them.
func (l *Lockout) Fail(key string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	l.sweep(now)
	f, ok := l.clients[key]
	if !ok && len(l.clients) >= l.maxClients {
		// Keep the clients locked out, forget the others' failures.
		for k, other := range l.clients {
			if !now.Before(other.lockedUntil) {
				delete(l.clients, k)
			}
		}
	}
	if !ok {
		f = &failures{since: now}
		l.clients[key] = f
	} else if now.Sub(f.since) > l.window {
		f.count, f.since = 0, now
	}
	f.count++
	if f.count >= l.failures {
		f.lockedUntil = now.Add(l.lockFor)
		f.count = 0
		f.since = now
	}
}

// sweep drops the entries whose window and lockout are over; mu must be
// held.
func (l *Lockout) sweep(now time.Time) {
	if now.Sub(l.lastSweep) < sweepEvery {
		return
	}
	l.lastSweep = now
	for key, f := range l.clients {
		if now.Sub(f.since) > l.window && !now.Before(f.lockedUntil) {
			delete(l.clients, key)
		}
	}
}
