// Package dnsresponder is the captive DNS of a connector VLAN interface.
//
// For every VLAN interface flagged "dns" in the connector's site networking it
// binds the interface address on port 53 (UDP and TCP) and answers every A
// query with that address, the way a captive-portal DNS does: whatever a
// device on the VLAN resolves, it lands on the connector's interface, where the
// portal (or a redirect to it) answers. AAAA queries get an empty NOERROR so
// dual-stack clients do not hang on IPv6; everything else is refused.
//
// There is no recursion and no upstream, so no amplification vector and no
// dependency on the tunnel.
package dnsresponder

import (
	"context"
	"fmt"
	"net"
	"sort"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/miekg/dns"
)

// TTL of the answers. Short: the device leaves the captive VLAN once
// registered and must not keep resolving everything to the portal.
const TTL = 60

// Interface is one VLAN interface to answer on.
type Interface struct {
	Name string
	IP   net.IP
}

// Status of one responder, for the admin UI.
type Status struct {
	Interface string `json:"interface"`
	IP        string `json:"ip"`
	State     string `json:"state"` // listening, error
	Error     string `json:"error,omitempty"`
	Queries   uint64 `json:"queries"`
}

// Config of the responder.
type Config struct {
	// Port to bind, 53 unless set (tests).
	Port int
	// Logger, optional.
	Logger func(format string, args ...any)
}

// Responder owns one UDP and one TCP server per interface.
type Responder struct {
	cfg     Config
	mu      sync.Mutex
	servers map[string]*server
}

// New creates a Responder. Call Sync to start listeners.
func New(cfg Config) *Responder {
	if cfg.Port == 0 {
		cfg.Port = 53
	}
	if cfg.Logger == nil {
		cfg.Logger = func(string, ...any) {}
	}
	return &Responder{cfg: cfg, servers: map[string]*server{}}
}

// Sync makes the running responders match ifaces: start new ones, stop
// removed ones, restart the ones in error or whose address changed. Safe to
// call every few seconds.
func (r *Responder) Sync(ctx context.Context, ifaces []Interface) {
	r.mu.Lock()
	defer r.mu.Unlock()
	wanted := map[string]Interface{}
	for _, i := range ifaces {
		if i.IP == nil || i.IP.To4() == nil {
			continue
		}
		wanted[i.Name] = i
	}
	for name, s := range r.servers {
		w, ok := wanted[name]
		if !ok || !w.IP.Equal(s.iface.IP) || s.failed() {
			s.stop()
			delete(r.servers, name)
			r.cfg.Logger("dns-responder: stopped on %s", name)
		}
	}
	for name, w := range wanted {
		if _, ok := r.servers[name]; ok {
			continue
		}
		s := newServer(r, w)
		r.servers[name] = s
		if err := s.start(); err != nil {
			s.setError(err)
			r.cfg.Logger("dns-responder: cannot listen on %s (%s): %s", name, w.IP, err)
			continue
		}
		r.cfg.Logger("dns-responder: answering on %s (%s)", name, w.IP)
	}
}

// Stop stops every responder.
func (r *Responder) Stop() {
	r.mu.Lock()
	defer r.mu.Unlock()
	for name, s := range r.servers {
		s.stop()
		delete(r.servers, name)
	}
}

// Status of every responder, sorted by interface name.
func (r *Responder) Status() []Status {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]Status, 0, len(r.servers))
	for _, s := range r.servers {
		out = append(out, s.status())
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Interface < out[j].Interface })
	return out
}

type server struct {
	responder *Responder
	iface     Interface
	udp, tcp  *dns.Server
	pc        net.PacketConn
	l         net.Listener
	mu        sync.Mutex
	err       error
	queries   atomic.Uint64
}

func newServer(r *Responder, iface Interface) *server {
	return &server{responder: r, iface: iface}
}

func (s *server) start() error {
	addr := net.JoinHostPort(s.iface.IP.String(), strconv.Itoa(s.responder.cfg.Port))
	handler := dns.HandlerFunc(s.serveDNS)

	pc, err := net.ListenPacket("udp4", addr)
	if err != nil {
		return fmt.Errorf("udp %s: %w", addr, err)
	}
	l, err := net.Listen("tcp4", addr)
	if err != nil {
		pc.Close()
		return fmt.Errorf("tcp %s: %w", addr, err)
	}
	s.pc, s.l = pc, l
	s.udp = &dns.Server{PacketConn: pc, Handler: handler, ReadTimeout: 2 * time.Second, WriteTimeout: 2 * time.Second}
	s.tcp = &dns.Server{Listener: l, Handler: handler, ReadTimeout: 2 * time.Second, WriteTimeout: 2 * time.Second}
	go s.serve(s.udp)
	go s.serve(s.tcp)
	return nil
}

func (s *server) serve(srv *dns.Server) {
	if err := srv.ActivateAndServe(); err != nil {
		s.mu.Lock()
		stopped := s.err != nil
		s.mu.Unlock()
		if !stopped {
			s.setError(fmt.Errorf("serve: %w", err))
			s.responder.cfg.Logger("dns-responder: %s: server stopped: %s", s.iface.Name, err)
		}
	}
}

// stop releases the sockets. dns.Server.Shutdown only acts once its serve
// loop has started, which may not be the case yet when a Sync immediately
// follows the start; closing the sockets ourselves covers that window (the
// serve loop then exits with an error, which serve() ignores once err is set).
func (s *server) stop() {
	s.setError(fmt.Errorf("stopped"))
	if s.udp != nil {
		s.udp.Shutdown()
	}
	if s.tcp != nil {
		s.tcp.Shutdown()
	}
	if s.pc != nil {
		s.pc.Close()
	}
	if s.l != nil {
		s.l.Close()
	}
}

func (s *server) failed() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.err != nil
}

func (s *server) setError(err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.err = err
}

func (s *server) status() Status {
	s.mu.Lock()
	defer s.mu.Unlock()
	st := Status{Interface: s.iface.Name, IP: s.iface.IP.String(), State: "listening", Queries: s.queries.Load()}
	if s.err != nil {
		st.State = "error"
		st.Error = s.err.Error()
	}
	return st
}

// serveDNS answers one query. A -> the interface address; AAAA -> empty
// NOERROR; anything else -> REFUSED. Non-query opcodes get NOTIMP.
func (s *server) serveDNS(w dns.ResponseWriter, req *dns.Msg) {
	s.queries.Add(1)
	m := new(dns.Msg)
	m.SetReply(req)
	m.Authoritative = true
	m.RecursionAvailable = false
	if req.Opcode != dns.OpcodeQuery || len(req.Question) == 0 {
		m.Rcode = dns.RcodeNotImplemented
		w.WriteMsg(m)
		return
	}
	q := req.Question[0]
	switch q.Qtype {
	case dns.TypeA, dns.TypeANY:
		m.Answer = append(m.Answer, &dns.A{
			Hdr: dns.RR_Header{Name: q.Name, Rrtype: dns.TypeA, Class: dns.ClassINET, Ttl: TTL},
			A:   s.iface.IP.To4(),
		})
	case dns.TypeAAAA:
		// Empty NOERROR: "no IPv6 address", so the client falls back to A.
	default:
		m.Rcode = dns.RcodeRefused
	}
	w.WriteMsg(m)
}

// lastStatus is exposed to the connector's local API.
var (
	lastStatusMu sync.RWMutex
	lastStatus   []Status
)

// SetLastStatus records the responder statuses.
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
