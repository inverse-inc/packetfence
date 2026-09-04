package dhcprelay

import (
	"bytes"
	"context"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	dhcp "github.com/inverse-inc/dhcp4"
)

// pipeConn is an in-memory net.PacketConn: the test injects datagrams with
// inject() and captures what the relay writes back with WriteTo.
type pipeConn struct {
	in     chan datagram
	mu     sync.Mutex
	out    []datagram
	closed chan struct{}
	once   sync.Once
}

type datagram struct {
	b    []byte
	addr net.Addr
}

func newPipeConn() *pipeConn {
	return &pipeConn{in: make(chan datagram, 16), closed: make(chan struct{})}
}

func (c *pipeConn) inject(b []byte, from net.Addr) { c.in <- datagram{b, from} }

func (c *pipeConn) ReadFrom(b []byte) (int, net.Addr, error) {
	select {
	case d := <-c.in:
		return copy(b, d.b), d.addr, nil
	case <-c.closed:
		return 0, nil, net.ErrClosed
	}
}

func (c *pipeConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.out = append(c.out, datagram{append([]byte(nil), b...), addr})
	return len(b), nil
}

func (c *pipeConn) Close() error {
	c.once.Do(func() { close(c.closed) })
	return nil
}
func (c *pipeConn) LocalAddr() net.Addr              { return &net.UDPAddr{Port: 67} }
func (c *pipeConn) SetDeadline(time.Time) error      { return nil }
func (c *pipeConn) SetReadDeadline(time.Time) error  { return nil }
func (c *pipeConn) SetWriteDeadline(time.Time) error { return nil }

type l2Send struct {
	iface Interface
	mac   net.HardwareAddr
	ip    net.IP
	body  []byte
}

type harness struct {
	relay  *Relay
	conn   *pipeConn
	l2mu   sync.Mutex
	l2     []l2Send
	server *httptest.Server
	// what the fake pfdhcp saw and what it answers
	seen   [][]byte
	answer func(req dhcp.Packet) (int, []byte)
}

func newHarness(t *testing.T) *harness {
	h := &harness{conn: newPipeConn()}
	h.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Content-Type") != ContentType {
			w.WriteHeader(http.StatusUnsupportedMediaType)
			return
		}
		body, _ := io.ReadAll(r.Body)
		h.seen = append(h.seen, body)
		code, reply := h.answer(dhcp.Packet(body))
		w.WriteHeader(code)
		w.Write(reply)
	}))
	t.Cleanup(h.server.Close)
	h.relay = New(Config{URL: h.server.URL, Timeout: time.Second, Logger: t.Logf})
	h.relay.openConn = func(Interface) (net.PacketConn, error) { return h.conn, nil }
	h.relay.sendL2 = func(iface Interface, mac net.HardwareAddr, ip net.IP, body []byte) error {
		h.l2mu.Lock()
		defer h.l2mu.Unlock()
		h.l2 = append(h.l2, l2Send{iface, mac, ip, append([]byte(nil), body...)})
		return nil
	}
	return h
}

var (
	vlanIP    = net.IPv4(10, 10, 100, 1)
	clientMAC = net.HardwareAddr{0x00, 0x11, 0x22, 0x33, 0x44, 0x55}
	offeredIP = net.IPv4(10, 10, 100, 50)
)

func discover(broadcast bool) dhcp.Packet {
	p := dhcp.RequestPacket(dhcp.Discover, clientMAC, nil, []byte{1, 2, 3, 4}, broadcast, nil)
	return p
}

func offerFor(req dhcp.Packet) []byte {
	return dhcp.ReplyPacket(req, dhcp.Offer, vlanIP, offeredIP, time.Hour, nil)
}

func waitFor(t *testing.T, cond func() bool) {
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("timed out waiting for the relay")
}

func TestRelayDiscoverUnicastOffer(t *testing.T) {
	h := newHarness(t)
	h.answer = func(req dhcp.Packet) (int, []byte) { return 200, offerFor(req) }
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	h.relay.Sync(ctx, []Interface{{Name: "eth0.100", IP: vlanIP}})
	defer h.relay.Stop()

	h.conn.inject(discover(false), &net.UDPAddr{IP: net.IPv4zero, Port: 68})
	waitFor(t, func() bool { h.l2mu.Lock(); defer h.l2mu.Unlock(); return len(h.l2) == 1 })

	// The request reached the server with giaddr = VLAN IP and hops bumped.
	if len(h.seen) != 1 {
		t.Fatalf("server saw %d requests", len(h.seen))
	}
	sent := dhcp.Packet(h.seen[0])
	if !sent.GIAddr().Equal(vlanIP) {
		t.Errorf("giaddr = %s, want %s", sent.GIAddr(), vlanIP)
	}
	if sent.Hops() != 1 {
		t.Errorf("hops = %d, want 1", sent.Hops())
	}
	// The offer went out as a layer-2 unicast to chaddr / yiaddr.
	got := h.l2[0]
	if !bytes.Equal(got.mac, clientMAC) || !got.ip.Equal(offeredIP) {
		t.Errorf("L2 unicast to %s/%s, want %s/%s", got.mac, got.ip, clientMAC, offeredIP)
	}
	if dhcp.Packet(got.body).OpCode() != dhcp.BootReply {
		t.Errorf("delivered packet is not a BOOTREPLY")
	}
	st := h.relay.Status()
	if len(st) != 1 || st[0].Requests != 1 || st[0].Replies != 1 || st[0].State != "listening" {
		t.Errorf("status = %+v", st)
	}
}

func TestRelayBroadcastFlagAndNak(t *testing.T) {
	h := newHarness(t)
	h.answer = func(req dhcp.Packet) (int, []byte) { return 200, offerFor(req) }
	ctx := context.Background()
	h.relay.Sync(ctx, []Interface{{Name: "eth0.100", IP: vlanIP}})
	defer h.relay.Stop()

	h.conn.inject(discover(true), &net.UDPAddr{IP: net.IPv4zero, Port: 68})
	waitFor(t, func() bool { h.l2mu.Lock(); defer h.l2mu.Unlock(); return len(h.l2) == 1 })
	if h.l2[0].mac.String() != "ff:ff:ff:ff:ff:ff" || !h.l2[0].ip.Equal(net.IPv4bcast) {
		t.Errorf("broadcast flag not honoured: %s/%s", h.l2[0].mac, h.l2[0].ip)
	}

	// A NAK has no yiaddr: broadcast regardless of the flag.
	h.answer = func(req dhcp.Packet) (int, []byte) {
		return 200, dhcp.ReplyPacket(req, dhcp.NAK, vlanIP, nil, 0, nil)
	}
	h.conn.inject(discover(false), &net.UDPAddr{IP: net.IPv4zero, Port: 68})
	waitFor(t, func() bool { h.l2mu.Lock(); defer h.l2mu.Unlock(); return len(h.l2) == 2 })
	if h.l2[1].mac.String() != "ff:ff:ff:ff:ff:ff" {
		t.Errorf("NAK not broadcast: %s", h.l2[1].mac)
	}
}

func TestRelayRenewIsPlainUnicast(t *testing.T) {
	h := newHarness(t)
	h.answer = func(req dhcp.Packet) (int, []byte) {
		return 200, dhcp.ReplyPacket(req, dhcp.ACK, vlanIP, req.CIAddr(), time.Hour, nil)
	}
	ctx := context.Background()
	h.relay.Sync(ctx, []Interface{{Name: "eth0.100", IP: vlanIP}})
	defer h.relay.Stop()

	req := dhcp.RequestPacket(dhcp.Request, clientMAC, offeredIP, []byte{9, 9, 9, 9}, false, nil)
	h.conn.inject(req, &net.UDPAddr{IP: offeredIP, Port: 68})
	waitFor(t, func() bool { h.conn.mu.Lock(); defer h.conn.mu.Unlock(); return len(h.conn.out) == 1 })
	out := h.conn.out[0]
	if ua := out.addr.(*net.UDPAddr); !ua.IP.Equal(offeredIP) || ua.Port != 68 {
		t.Errorf("renew ACK sent to %s", out.addr)
	}
	if len(h.l2) != 0 {
		t.Errorf("renew must not use the raw socket")
	}
}

func TestRelayDropsOnServerErrorsAndIgnoresReplies(t *testing.T) {
	h := newHarness(t)
	h.answer = func(req dhcp.Packet) (int, []byte) { return 204, nil }
	ctx := context.Background()
	h.relay.Sync(ctx, []Interface{{Name: "eth0.100", IP: vlanIP}})
	defer h.relay.Stop()

	h.conn.inject(discover(false), &net.UDPAddr{IP: net.IPv4zero, Port: 68})
	waitFor(t, func() bool { return len(h.seen) == 1 })
	time.Sleep(20 * time.Millisecond)
	if len(h.l2) != 0 {
		t.Errorf("204 must deliver nothing")
	}

	h.answer = func(req dhcp.Packet) (int, []byte) { return 403, []byte("giaddr not yours") }
	h.conn.inject(discover(false), &net.UDPAddr{IP: net.IPv4zero, Port: 68})
	waitFor(t, func() bool { return h.relay.Status()[0].Dropped == 1 })
	if st := h.relay.Status()[0]; st.LastError == "" || st.State != "listening" {
		t.Errorf("status after 403: %+v", st)
	}

	// A BOOTREPLY arriving on the wire (another server's offer) is not relayed.
	h.conn.inject(offerFor(discover(false)), &net.UDPAddr{IP: vlanIP, Port: 67})
	time.Sleep(20 * time.Millisecond)
	if len(h.seen) != 2 {
		t.Errorf("a BOOTREPLY was relayed upstream")
	}
}

func TestSyncStartsStopsAndRestarts(t *testing.T) {
	h := newHarness(t)
	h.answer = func(req dhcp.Packet) (int, []byte) { return 204, nil }
	opened := 0
	h.relay.openConn = func(Interface) (net.PacketConn, error) { opened++; return newPipeConn(), nil }
	ctx := context.Background()

	h.relay.Sync(ctx, []Interface{{Name: "eth0.100", IP: vlanIP}, {Name: "eth0.101", IP: net.IPv4(10, 10, 101, 1)}})
	if len(h.relay.Status()) != 2 || opened != 2 {
		t.Fatalf("expected 2 listeners, got %d (opened %d)", len(h.relay.Status()), opened)
	}
	// Same input: nothing reopened.
	h.relay.Sync(ctx, []Interface{{Name: "eth0.100", IP: vlanIP}, {Name: "eth0.101", IP: net.IPv4(10, 10, 101, 1)}})
	if opened != 2 {
		t.Errorf("idempotent Sync reopened sockets")
	}
	// Address change restarts that listener; removal stops the other.
	h.relay.Sync(ctx, []Interface{{Name: "eth0.100", IP: net.IPv4(10, 10, 100, 2)}})
	st := h.relay.Status()
	if len(st) != 1 || st[0].IP != "10.10.100.2" || opened != 3 {
		t.Errorf("after change: %+v (opened %d)", st, opened)
	}
	h.relay.Stop()
	if len(h.relay.Status()) != 0 {
		t.Errorf("Stop left listeners")
	}
}
