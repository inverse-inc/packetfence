package forward

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/coredns/coredns/plugin/pkg/dnstest"
	"github.com/coredns/coredns/plugin/pkg/transport"
	"github.com/coredns/coredns/plugin/test"

	"github.com/miekg/dns"
)

// restoreHealthTimeouts snapshots the package-level timing globals and restores
// them when the test finishes. These globals (hcReadTimeout, hcWriteTimeout,
// readTimeout, defaultTimeout, hcInterval) are shared across every test in the
// package and were previously left mutated. In particular TestHealthMaxFails and
// TestHealthNoMaxFails set hcInterval to 10ms; without restoration that value
// leaks into other health tests under `go test -count=N`, `-shuffle`, or any
// `-run` reordering, making them flaky (a 10ms retry interval lets a single
// health check fire twice inside the assertion window).
func restoreHealthTimeouts(t *testing.T) {
	t.Helper()
	hcRead, hcWrite := hcReadTimeout, hcWriteTimeout
	read, def, interval := readTimeout, defaultTimeout, hcInterval
	t.Cleanup(func() {
		hcReadTimeout = hcRead
		hcWriteTimeout = hcWrite
		readTimeout = read
		defaultTimeout = def
		hcInterval = interval
	})
}

// waitForCount polls counter until it reaches at least want or timeout elapses,
// returning the last observed value. It replaces fixed time.Sleep calls so the
// health tests no longer race a fixed window against the asynchronous
// health-check goroutine.
func waitForCount(counter *uint32, want uint32, timeout time.Duration) uint32 {
	deadline := time.Now().Add(timeout)
	for {
		got := atomic.LoadUint32(counter)
		if got >= want || time.Now().After(deadline) {
			return got
		}
		time.Sleep(time.Millisecond)
	}
}

// waitForDown polls until p.Down(maxfails) is true or timeout elapses.
func waitForDown(p *Proxy, maxfails uint32, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for {
		if p.Down(maxfails) {
			return true
		}
		if time.Now().After(deadline) {
			return false
		}
		time.Sleep(time.Millisecond)
	}
}

func TestHealth(t *testing.T) {
	restoreHealthTimeouts(t)
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond

	i := uint32(0)
	q := uint32(0)
	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		if atomic.LoadUint32(&q) == 0 { //drop the first query to trigger health-checking
			atomic.AddUint32(&q, 1)
			return
		}
		if r.Question[0].Name == "." && r.RecursionDesired == true {
			atomic.AddUint32(&i, 1)
		}
		ret := new(dns.Msg)
		ret.SetReply(r)
		w.WriteMsg(ret)
	})
	defer s.Close()

	p := NewProxy(s.Addr, transport.DNS)
	f := New()
	f.SetProxy(p)
	defer f.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	f.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	i1 := waitForCount(&i, 1, time.Second)
	if i1 != 1 {
		t.Errorf("Expected number of health checks with RecursionDesired==true to be %d, got %d", 1, i1)
	}
}

func TestHealthTCP(t *testing.T) {
	restoreHealthTimeouts(t)
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond

	i := uint32(0)
	q := uint32(0)
	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		if atomic.LoadUint32(&q) == 0 { //drop the first query to trigger health-checking
			atomic.AddUint32(&q, 1)
			return
		}
		if r.Question[0].Name == "." && r.RecursionDesired == true {
			atomic.AddUint32(&i, 1)
		}
		ret := new(dns.Msg)
		ret.SetReply(r)
		w.WriteMsg(ret)
	})
	defer s.Close()

	p := NewProxy(s.Addr, transport.DNS)
	p.health.SetTCPTransport()
	f := New()
	f.SetProxy(p)
	defer f.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	f.ServeDNS(context.TODO(), &test.ResponseWriter{TCP: true}, req)

	i1 := waitForCount(&i, 1, time.Second)
	if i1 != 1 {
		t.Errorf("Expected number of health checks with RecursionDesired==true to be %d, got %d", 1, i1)
	}
}

func TestHealthNoRecursion(t *testing.T) {
	restoreHealthTimeouts(t)
	hcReadTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond

	i := uint32(0)
	q := uint32(0)
	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		if atomic.LoadUint32(&q) == 0 { //drop the first query to trigger health-checking
			atomic.AddUint32(&q, 1)
			return
		}
		if r.Question[0].Name == "." && r.RecursionDesired == false {
			atomic.AddUint32(&i, 1)
		}
		ret := new(dns.Msg)
		ret.SetReply(r)
		w.WriteMsg(ret)
	})
	defer s.Close()

	p := NewProxy(s.Addr, transport.DNS)
	p.health.SetRecursionDesired(false)
	f := New()
	f.SetProxy(p)
	defer f.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	f.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	i1 := waitForCount(&i, 1, time.Second)
	if i1 != 1 {
		t.Errorf("Expected number of health checks with RecursionDesired==false to be %d, got %d", 1, i1)
	}
}

func TestHealthTimeout(t *testing.T) {
	restoreHealthTimeouts(t)
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond

	i := uint32(0)
	q := uint32(0)
	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		if r.Question[0].Name == "." {
			// health check, answer
			atomic.AddUint32(&i, 1)
			ret := new(dns.Msg)
			ret.SetReply(r)
			w.WriteMsg(ret)
			return
		}
		if atomic.LoadUint32(&q) == 0 { //drop only first query
			atomic.AddUint32(&q, 1)
			return
		}
		ret := new(dns.Msg)
		ret.SetReply(r)
		w.WriteMsg(ret)
	})
	defer s.Close()

	p := NewProxy(s.Addr, transport.DNS)
	f := New()
	f.SetProxy(p)
	defer f.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	f.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	i1 := waitForCount(&i, 1, time.Second)
	if i1 != 1 {
		t.Errorf("Expected number of health checks to be %d, got %d", 1, i1)
	}
}

func TestHealthMaxFails(t *testing.T) {
	restoreHealthTimeouts(t)
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	hcInterval = 10 * time.Millisecond

	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		// timeout
	})
	defer s.Close()

	p := NewProxy(s.Addr, transport.DNS)
	f := New()
	f.maxfails = 2
	f.SetProxy(p)
	defer f.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	f.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	if !waitForDown(p, f.maxfails, time.Second) {
		fails := atomic.LoadUint32(&p.fails)
		t.Errorf("Expected Proxy fails to be greater than %d, got %d", f.maxfails, fails)
	}
}

func TestHealthNoMaxFails(t *testing.T) {
	restoreHealthTimeouts(t)
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	hcInterval = 10 * time.Millisecond

	i := uint32(0)
	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		if r.Question[0].Name == "." {
			// health check, answer
			atomic.AddUint32(&i, 1)
			ret := new(dns.Msg)
			ret.SetReply(r)
			w.WriteMsg(ret)
		}
	})
	defer s.Close()

	p := NewProxy(s.Addr, transport.DNS)
	f := New()
	f.maxfails = 0
	f.SetProxy(p)
	defer f.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	f.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	// With maxfails==0 no health check is ever kicked off; give it a window to
	// (incorrectly) fire and confirm it stayed at 0.
	time.Sleep(100 * time.Millisecond)
	i1 := atomic.LoadUint32(&i)
	if i1 != 0 {
		t.Errorf("Expected number of health checks to be %d, got %d", 0, i1)
	}
}

func TestHealthDomain(t *testing.T) {
	restoreHealthTimeouts(t)
	hcReadTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	hcDomain := "example.org."
	i := uint32(0)
	q := uint32(0)
	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		if atomic.LoadUint32(&q) == 0 { //drop the first query to trigger health-checking
			atomic.AddUint32(&q, 1)
			return
		}
		if r.Question[0].Name == hcDomain && r.RecursionDesired == true {
			atomic.AddUint32(&i, 1)
		}
		ret := new(dns.Msg)
		ret.SetReply(r)
		w.WriteMsg(ret)
	})
	defer s.Close()
	p := NewProxy(s.Addr, transport.DNS)
	p.health.SetDomain(hcDomain)
	f := New()
	f.SetProxy(p)
	defer f.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion(".", dns.TypeNS)

	f.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	i1 := waitForCount(&i, 1, time.Second)
	if i1 != 1 {
		t.Errorf("Expected number of health checks with Domain==%s to be %d, got %d", hcDomain, 1, i1)
	}
}
