package forward

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/coredns/plugin/pkg/dnstest"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/pkg/transport"
	"github.com/inverse-inc/packetfence/go/coredns/plugin/test"

	"github.com/miekg/dns"
)

func TestHealth(t *testing.T) {
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	const expected = 1
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

	f.proxies = append(f.proxies, p)
	f.SetProxy(p)

	ForwardEntry := Forwards{}
	var forward []*Forward
	forward = append(forward, f)
	ForwardEntry.Forward = forward

	defer ForwardEntry.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	ForwardEntry.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	time.Sleep(20 * time.Millisecond)
	i1 := atomic.LoadUint32(&i)
	if i1 != expected {
		t.Errorf("Expected number of health checks with RecursionDesired==true to be %d, got %d", expected, i1)
	}
}

func TestHealthNoRecursion(t *testing.T) {
	hcReadTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	const expected = 1
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

	ForwardEntry := Forwards{}
	var forward []*Forward
	forward = append(forward, f)
	ForwardEntry.Forward = forward

	defer ForwardEntry.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	ForwardEntry.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	time.Sleep(1 * time.Second)
	i1 := atomic.LoadUint32(&i)
	if i1 != expected {
		t.Errorf("Expected number of health checks with RecursionDesired==false to be %d, got %d", expected, i1)
	}
}

func TestHealthTimeout(t *testing.T) {
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond

	const expected = 1
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
	ForwardEntry := Forwards{}
	var forward []*Forward
	forward = append(forward, f)
	ForwardEntry.Forward = forward

	defer ForwardEntry.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	ForwardEntry.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	time.Sleep(1 * time.Second)
	i1 := atomic.LoadUint32(&i)
	if i1 != expected {
		t.Errorf("Expected number of health checks to be %d, got %d", expected, i1)
	}
}

func TestHealthFailTwice(t *testing.T) {
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	hcInterval = 10 * time.Millisecond

	const expected = 2
	i := uint32(0)
	q := uint32(0)
	s := dnstest.NewServer(func(w dns.ResponseWriter, r *dns.Msg) {
		if r.Question[0].Name == "." {
			atomic.AddUint32(&i, 1)
			i1 := atomic.LoadUint32(&i)
			// Timeout health until we get the second one
			if i1 < 2 {
				return
			}
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
	ForwardEntry := Forwards{}
	var forward []*Forward
	forward = append(forward, f)
	ForwardEntry.Forward = forward

	defer ForwardEntry.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	ForwardEntry.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	time.Sleep(30 * time.Millisecond)
	i1 := atomic.LoadUint32(&i)
	if i1 != expected {
		t.Logf("Expected number of health checks to be %d, got %d", expected, i1)
	}
}

func TestHealthMaxFails(t *testing.T) {
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
	ForwardEntry := Forwards{}
	var forward []*Forward
	forward = append(forward, f)
	ForwardEntry.Forward = forward

	defer ForwardEntry.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	ForwardEntry.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	time.Sleep(100 * time.Millisecond)
	fails := atomic.LoadUint32(&p.fails)
	if !p.Down(f.maxfails) {
		t.Errorf("Expected Proxy fails to be greater than %d, got %d", f.maxfails, fails)
	}
}

func TestHealthNoMaxFails(t *testing.T) {
	hcReadTimeout = 10 * time.Millisecond
	hcWriteTimeout = 10 * time.Millisecond
	readTimeout = 10 * time.Millisecond
	defaultTimeout = 10 * time.Millisecond
	hcInterval = 10 * time.Millisecond

	const expected = 0
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
	ForwardEntry := Forwards{}
	var forward []*Forward
	forward = append(forward, f)
	ForwardEntry.Forward = forward

	defer ForwardEntry.OnShutdown()

	req := new(dns.Msg)
	req.SetQuestion("example.org.", dns.TypeA)

	ForwardEntry.ServeDNS(context.TODO(), &test.ResponseWriter{}, req)

	time.Sleep(1 * time.Second)
	i1 := atomic.LoadUint32(&i)
	if i1 != expected {
		t.Errorf("Expected number of health checks to be %d, got %d", expected, i1)
	}
}
