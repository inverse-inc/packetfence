// Package dhcprelay is the connector-side half of DHCP-over-HTTPS.
//
// For every VLAN interface flagged "dhcp" in the connector's site networking,
// it listens on UDP/67, wraps each BOOTREQUEST in an HTTP POST to the
// pfconnector server (through the tunnel-local bind), sets giaddr to the
// interface address so the central pfdhcp picks the right scope and
// advertises that address as DHCP server, and delivers the reply body to the
// client the way a classic relay agent does (RFC 1542 §4.1.2): broadcast when
// the client asked for it or has no address yet, layer-2 unicast to the
// offered address otherwise.
//
// It is modelled on the relay mode of github.com/fdurand/standalone_dhcp with
// the UDP forward replaced by the HTTP round trip. There is no queue and no
// retry: a request that cannot be answered within Timeout is dropped and the
// client retransmits, pfdhcp's transaction lock dedups the retransmission.
package dhcprelay

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	dhcp "github.com/inverse-inc/dhcp4"
)

// ContentType is the media type of a raw DHCP message body, mirroring
// application/dns-message of RFC 8484.
const ContentType = "application/dhcp-message"

const (
	bootpServerPort = 67
	bootpClientPort = 68
	minDHCPLength   = 240  // fixed BOOTP header + magic cookie
	maxDHCPLength   = 1500 // we never relay anything larger than an MTU
)

// Config of the relay.
type Config struct {
	// URL the DHCP messages are POSTed to, e.g.
	// http://127.0.0.1:22226/api/v1/pfconnector/dhcp-message?connector-id=<id>
	URL string
	// Timeout of one HTTP round trip. DHCP clients retransmit after ~4s, so
	// this must stay well below that. Default 1500ms.
	Timeout time.Duration
	// Logger, optional.
	Logger func(format string, args ...interface{})
}

// Interface is one VLAN interface to relay on.
type Interface struct {
	Name string
	IP   net.IP
}

// Status of one relay listener, for the admin UI.
type Status struct {
	Interface string `json:"interface"`
	IP        string `json:"ip"`
	State     string `json:"state"` // listening, error
	Error     string `json:"error,omitempty"`
	Requests  uint64 `json:"requests"`
	Replies   uint64 `json:"replies"`
	Dropped   uint64 `json:"dropped"`
	LastError string `json:"last_error,omitempty"`
}

// Relay owns one listener per interface.
type Relay struct {
	cfg       Config
	client    *http.Client
	mu        sync.Mutex
	listeners map[string]*listener
	// Hooks for tests: open the sockets and send replies.
	openConn func(iface Interface) (net.PacketConn, error)
	sendL2   func(iface Interface, dstMAC net.HardwareAddr, dstIP net.IP, payload []byte) error
}

// New creates a Relay. Call Sync to start listeners.
func New(cfg Config) *Relay {
	if cfg.Timeout == 0 {
		cfg.Timeout = 1500 * time.Millisecond
	}
	if cfg.Logger == nil {
		cfg.Logger = func(string, ...interface{}) {}
	}
	return &Relay{
		cfg:       cfg,
		client:    &http.Client{Timeout: cfg.Timeout},
		listeners: map[string]*listener{},
		openConn:  openBroadcastConn,
		sendL2:    sendLayer2,
	}
}

// Sync makes the set of running listeners match ifaces: new interfaces get a
// listener, removed ones are stopped, listeners in error are retried, and an
// interface whose address changed is restarted. Safe to call every few
// seconds.
func (r *Relay) Sync(ctx context.Context, ifaces []Interface) {
	r.mu.Lock()
	defer r.mu.Unlock()

	wanted := map[string]Interface{}
	for _, i := range ifaces {
		if i.IP == nil || i.IP.To4() == nil {
			continue
		}
		wanted[i.Name] = i
	}
	for name, l := range r.listeners {
		w, ok := wanted[name]
		if !ok || !w.IP.Equal(l.iface.IP) || l.failed() {
			l.stop()
			delete(r.listeners, name)
			r.cfg.Logger("dhcp-relay: stopped listener on %s", name)
		}
	}
	for name, w := range wanted {
		if _, ok := r.listeners[name]; ok {
			continue
		}
		l := newListener(r, w)
		r.listeners[name] = l
		if err := l.start(ctx); err != nil {
			l.setError(err)
			r.cfg.Logger("dhcp-relay: cannot listen on %s (%s): %s", name, w.IP, err)
			continue
		}
		r.cfg.Logger("dhcp-relay: listening on %s (%s)", name, w.IP)
	}
}

// Stop stops every listener.
func (r *Relay) Stop() {
	r.mu.Lock()
	defer r.mu.Unlock()
	for name, l := range r.listeners {
		l.stop()
		delete(r.listeners, name)
	}
}

// Status of every listener, sorted by interface name.
func (r *Relay) Status() []Status {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]Status, 0, len(r.listeners))
	for _, l := range r.listeners {
		out = append(out, l.status())
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Interface < out[j].Interface })
	return out
}

type listener struct {
	relay  *Relay
	iface  Interface
	conn   net.PacketConn
	cancel context.CancelFunc
	done   chan struct{}

	mu        sync.Mutex
	err       error
	lastError string
	requests  atomic.Uint64
	replies   atomic.Uint64
	dropped   atomic.Uint64
}

func newListener(r *Relay, iface Interface) *listener {
	return &listener{relay: r, iface: iface, done: make(chan struct{})}
}

func (l *listener) start(ctx context.Context) error {
	conn, err := l.relay.openConn(l.iface)
	if err != nil {
		close(l.done)
		return err
	}
	l.conn = conn
	ctx, l.cancel = context.WithCancel(ctx)
	go l.serve(ctx)
	return nil
}

func (l *listener) stop() {
	if l.cancel != nil {
		l.cancel()
	}
	if l.conn != nil {
		l.conn.Close()
	}
	<-l.done
}

func (l *listener) failed() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.err != nil
}

func (l *listener) setError(err error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.err = err
}

func (l *listener) noteError(err error) {
	l.dropped.Add(1)
	l.mu.Lock()
	l.lastError = err.Error()
	l.mu.Unlock()
}

func (l *listener) status() Status {
	l.mu.Lock()
	defer l.mu.Unlock()
	st := Status{
		Interface: l.iface.Name,
		IP:        l.iface.IP.String(),
		State:     "listening",
		Requests:  l.requests.Load(),
		Replies:   l.replies.Load(),
		Dropped:   l.dropped.Load(),
		LastError: l.lastError,
	}
	if l.err != nil {
		st.State = "error"
		st.Error = l.err.Error()
	}
	return st
}

// serve reads BOOTREQUESTs until the socket is closed. Each request is
// relayed in its own goroutine so a slow tunnel never blocks the socket.
func (l *listener) serve(ctx context.Context) {
	defer close(l.done)
	buf := make([]byte, 2048)
	for {
		n, addr, err := l.conn.ReadFrom(buf)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			l.setError(fmt.Errorf("read: %w", err))
			l.relay.cfg.Logger("dhcp-relay: %s: read error, listener stopped: %s", l.iface.Name, err)
			return
		}
		if n < minDHCPLength || n > maxDHCPLength {
			continue
		}
		p := dhcp.Packet(append([]byte(nil), buf[:n]...))
		if p.OpCode() != dhcp.BootRequest || p.HLen() > 16 {
			continue
		}
		go l.relayOne(ctx, p, addr)
	}
}

// relayOne forwards one request over HTTP and delivers the reply.
func (l *listener) relayOne(ctx context.Context, p dhcp.Packet, from net.Addr) {
	l.requests.Add(1)
	logger := l.relay.cfg.Logger
	mac := p.CHAddr().String()

	// giaddr: set to our address when the client talked to us directly.
	// A request that already carries a giaddr came through another relay;
	// keep it, the central server still needs it to select the scope.
	if p.GIAddr().Equal(net.IPv4zero) {
		p.SetGIAddr(l.iface.IP.To4())
	}
	if p.Hops() < 255 {
		p.SetHops(p.Hops() + 1)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, l.relay.cfg.URL, bytes.NewReader(p))
	if err != nil {
		l.noteError(err)
		return
	}
	req.Header.Set("Content-Type", ContentType)
	res, err := l.relay.client.Do(req)
	if err != nil {
		l.noteError(err)
		logger("dhcp-relay: %s: %s from %s dropped: %s", l.iface.Name, msgTypeOf(p), mac, err)
		return
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusNoContent {
		// The server had nothing to say (unknown scope, transaction dedup...).
		return
	}
	if res.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(res.Body, 512))
		err := fmt.Errorf("server replied %d: %s", res.StatusCode, bytes.TrimSpace(body))
		l.noteError(err)
		logger("dhcp-relay: %s: %s from %s dropped: %s", l.iface.Name, msgTypeOf(p), mac, err)
		return
	}
	body, err := io.ReadAll(io.LimitReader(res.Body, maxDHCPLength+1))
	if err != nil || len(body) < minDHCPLength || len(body) > maxDHCPLength {
		l.noteError(fmt.Errorf("invalid reply body (%d bytes)", len(body)))
		return
	}
	reply := dhcp.Packet(body)
	if reply.OpCode() != dhcp.BootReply || !bytes.Equal(reply.XId(), p.XId()) {
		l.noteError(fmt.Errorf("reply is not a BOOTREPLY for xid %x", p.XId()))
		return
	}
	if err := l.deliver(reply, from); err != nil {
		l.noteError(err)
		logger("dhcp-relay: %s: cannot deliver %s to %s: %s", l.iface.Name, msgTypeOf(reply), mac, err)
		return
	}
	l.replies.Add(1)
	logger("dhcp-relay: %s: %s %s -> %s %s", l.iface.Name, msgTypeOf(p), mac, msgTypeOf(reply), reply.YIAddr())
}

// deliver hands a BOOTREPLY to the client on our interface, following the
// relay agent rules of RFC 1542 §4.1.2 and RFC 2131 §4.1.
func (l *listener) deliver(reply dhcp.Packet, from net.Addr) error {
	// A client that already has an address (renew/rebind/inform) sent us a
	// unicast from that address; answer with a plain unicast to it. The
	// kernel can ARP it, the client owns the address.
	if ua, ok := from.(*net.UDPAddr); ok && ua.IP != nil && !ua.IP.Equal(net.IPv4zero) && !ua.IP.IsUnspecified() {
		_, err := l.conn.WriteTo(reply, &net.UDPAddr{IP: ua.IP, Port: bootpClientPort})
		return err
	}
	// Broadcast when the client asked for it, or when there is no address to
	// unicast to (NAK, or an offer without yiaddr).
	if reply.Broadcast() || reply.YIAddr().Equal(net.IPv4zero) {
		return l.relay.sendL2(l.iface, net.HardwareAddr{0xff, 0xff, 0xff, 0xff, 0xff, 0xff}, net.IPv4bcast, reply)
	}
	// Layer-2 unicast to the offered address: the client does not own the
	// address yet so ARP would fail; use chaddr directly.
	return l.relay.sendL2(l.iface, reply.CHAddr(), reply.YIAddr(), reply)
}

func msgTypeOf(p dhcp.Packet) string {
	opts := p.ParseOptions()
	if t := opts[dhcp.OptionDHCPMessageType]; len(t) == 1 {
		return dhcp.MessageType(t[0]).String()
	}
	return "BOOTP"
}

var (
	lastStatusMu sync.RWMutex
	lastStatus   []Status
)

// SetLastStatus records the listener statuses for the connector's local API.
func SetLastStatus(s []Status) {
	lastStatusMu.Lock()
	defer lastStatusMu.Unlock()
	lastStatus = append([]Status(nil), s...)
}

// LastStatus returns the statuses recorded by SetLastStatus (nil before the
// first Sync).
func LastStatus() []Status {
	lastStatusMu.RLock()
	defer lastStatusMu.RUnlock()
	return lastStatus
}
