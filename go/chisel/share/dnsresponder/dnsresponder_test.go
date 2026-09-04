package dnsresponder

import (
	"context"
	"net"
	"strconv"
	"testing"
	"time"

	"github.com/miekg/dns"
)

// freePort asks the kernel for an unused UDP+TCP port on loopback.
func freePort(t *testing.T) int {
	t.Helper()
	for range 20 {
		l, err := net.Listen("tcp4", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		port := l.Addr().(*net.TCPAddr).Port
		l.Close()
		pc, err := net.ListenPacket("udp4", net.JoinHostPort("127.0.0.1", itoa(port)))
		if err != nil {
			continue
		}
		pc.Close()
		return port
	}
	t.Fatal("no free port")
	return 0
}

func itoa(i int) string { return strconv.Itoa(i) }

func query(t *testing.T, netw, addr, name string, qtype uint16) *dns.Msg {
	t.Helper()
	c := &dns.Client{Net: netw, Timeout: 2 * time.Second}
	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), qtype)
	m.RecursionDesired = true
	res, _, err := c.Exchange(m, addr)
	if err != nil {
		t.Fatalf("%s query %s: %s", netw, name, err)
	}
	return res
}

func TestResponderAnswersWithInterfaceAddress(t *testing.T) {
	port := freePort(t)
	r := New(Config{Port: port, Logger: t.Logf})
	ip := net.IPv4(127, 0, 0, 1)
	r.Sync(context.Background(), []Interface{{Name: "lo.100", IP: ip}})
	defer r.Stop()
	addr := net.JoinHostPort("127.0.0.1", itoa(port))

	for _, netw := range []string{"udp", "tcp"} {
		res := query(t, netw, addr, "www.example.com", dns.TypeA)
		if res.Rcode != dns.RcodeSuccess || len(res.Answer) != 1 {
			t.Fatalf("%s: rcode %d answers %d", netw, res.Rcode, len(res.Answer))
		}
		a, ok := res.Answer[0].(*dns.A)
		if !ok || !a.A.Equal(ip) || a.Hdr.Ttl != TTL || a.Hdr.Name != "www.example.com." {
			t.Errorf("%s: answer %v", netw, res.Answer[0])
		}
		if !res.Authoritative || res.RecursionAvailable {
			t.Errorf("%s: flags aa=%v ra=%v", netw, res.Authoritative, res.RecursionAvailable)
		}
	}

	res := query(t, "udp", addr, "ipv6.example.com", dns.TypeAAAA)
	if res.Rcode != dns.RcodeSuccess || len(res.Answer) != 0 {
		t.Errorf("AAAA: rcode %d answers %d, want empty NOERROR", res.Rcode, len(res.Answer))
	}
	res = query(t, "udp", addr, "example.com", dns.TypeMX)
	if res.Rcode != dns.RcodeRefused {
		t.Errorf("MX: rcode %d, want REFUSED", res.Rcode)
	}

	st := r.Status()
	if len(st) != 1 || st[0].State != "listening" || st[0].Queries != 4 || st[0].IP != "127.0.0.1" {
		t.Errorf("status %+v", st)
	}
}

func TestSyncLifecycle(t *testing.T) {
	port := freePort(t)
	r := New(Config{Port: port})
	ctx := context.Background()
	ip := net.IPv4(127, 0, 0, 1)

	r.Sync(ctx, []Interface{{Name: "lo.100", IP: ip}})
	if len(r.Status()) != 1 {
		t.Fatal("not started")
	}
	// Same input: still one, still the same server (port stays bound).
	r.Sync(ctx, []Interface{{Name: "lo.100", IP: ip}})
	if len(r.Status()) != 1 {
		t.Fatal("duplicated")
	}
	// A second interface on the same address cannot bind: reported, not fatal.
	r.Sync(ctx, []Interface{{Name: "lo.100", IP: ip}, {Name: "lo.101", IP: ip}})
	st := r.Status()
	if len(st) != 2 || st[1].State != "error" || st[0].State != "listening" {
		t.Errorf("conflict: %+v", st)
	}
	// Removing the first frees the port; the errored one is retried and wins.
	r.Sync(ctx, []Interface{{Name: "lo.101", IP: ip}})
	if st := r.Status(); len(st) != 1 || st[0].Interface != "lo.101" || st[0].State != "listening" {
		t.Errorf("after removal: %+v", st)
	}
	r.Stop()
	if len(r.Status()) != 0 {
		t.Error("Stop left servers")
	}
	// Port is free again.
	l, err := net.Listen("tcp4", net.JoinHostPort("127.0.0.1", itoa(port)))
	if err != nil {
		t.Fatalf("port not released: %s", err)
	}
	l.Close()
}
