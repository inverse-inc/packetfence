package tunnel

import (
	"io"
	"net"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// Stats are the live counters of one tunnel: the bytes carried by its
// transport in each direction, the last keepalive round trip and the moment
// the SSH connection came up. They feed the connectors topology view in the
// admin UI (bytes per second between two samples, latency, health).
//
// Directions are those of the process holding the tunnel: BytesIn is what it
// read from the peer, BytesOut what it wrote. On the pfconnector server,
// "in" is therefore traffic coming from the site.
type Stats struct {
	bytesIn          atomic.Int64
	bytesOut         atomic.Int64
	lastRTTNanos     atomic.Int64
	pings            atomic.Int64
	connectedAtNanos atomic.Int64

	servicesMu sync.Mutex
	services   map[string]*serviceCounters
}

// StatsSnapshot is the JSON form of Stats at one instant.
type StatsSnapshot struct {
	BytesIn  int64 `json:"bytes_in"`
	BytesOut int64 `json:"bytes_out"`
	// RTTMs is the last keepalive round trip in milliseconds, 0 before the
	// first one.
	RTTMs float64 `json:"rtt_ms"`
	Pings int64   `json:"pings"`
	// Channels is the number of proxied connections open right now.
	Channels    int32      `json:"channels"`
	ConnectedAt *time.Time `json:"connected_at,omitempty"`
	SampledAt   time.Time  `json:"sampled_at"`
	// Services breaks the traffic down per destination.
	Services []ServiceStats `json:"services"`
}

// NewStats returns zeroed counters. Pass them in Config.Stats when the
// transport must be metered before the tunnel exists (the server meters the
// websocket connection before the SSH handshake).
func NewStats() *Stats {
	return &Stats{}
}

// MeterConn wraps a transport connection so its bytes are counted.
func (s *Stats) MeterConn(c net.Conn) net.Conn {
	return &meteredConn{Conn: c, stats: s}
}

type meteredConn struct {
	net.Conn
	stats *Stats
}

func (m *meteredConn) Read(b []byte) (int, error) {
	n, err := m.Conn.Read(b)
	if n > 0 {
		m.stats.bytesIn.Add(int64(n))
	}
	return n, err
}

func (m *meteredConn) Write(b []byte) (int, error) {
	n, err := m.Conn.Write(b)
	if n > 0 {
		m.stats.bytesOut.Add(int64(n))
	}
	return n, err
}

func (s *Stats) recordRTT(d time.Duration) {
	s.lastRTTNanos.Store(int64(d))
	s.pings.Add(1)
}

func (s *Stats) connected(at time.Time) {
	s.connectedAtNanos.Store(at.UnixNano())
}

func (s *Stats) snapshot(channels int32) StatsSnapshot {
	out := StatsSnapshot{
		BytesIn:   s.bytesIn.Load(),
		BytesOut:  s.bytesOut.Load(),
		RTTMs:     float64(s.lastRTTNanos.Load()) / float64(time.Millisecond),
		Pings:     s.pings.Load(),
		Channels:  channels,
		SampledAt: time.Now(),
		Services:  s.servicesSnapshot(),
	}
	if at := s.connectedAtNanos.Load(); at != 0 {
		t := time.Unix(0, at)
		out.ConnectedAt = &t
	}
	return out
}

// Stats returns the tunnel's counters at this instant.
func (t *Tunnel) Stats() StatsSnapshot {
	return t.stats.snapshot(t.connStats.Active())
}

// Per-service counters. Every SSH channel of the tunnel carries traffic for
// one destination ("host:port/proto", plus the handler when there is one):
// RADIUS to the cloud, the portal, MySQL, the Fingerbank egress... Counting
// the bytes read from and written to each channel, keyed by that destination,
// gives the topology view a breakdown of what the tunnel carries.

type serviceCounters struct {
	bytesIn, bytesOut atomic.Int64
	active            atomic.Int32
	connections       atomic.Int64
}

// ServiceStats is the JSON form of one destination's counters.
type ServiceStats struct {
	// Destination is "host:port/proto" as dialed, plus "|handler" for the
	// radius and proxyproto handlers.
	Destination string `json:"destination"`
	// Reverse is set for channels the server opened toward the connector
	// (its reverse binds, e.g. the Fingerbank collector), as opposed to the
	// connector's own listeners.
	Reverse     bool  `json:"reverse,omitempty"`
	BytesIn     int64 `json:"bytes_in"`
	BytesOut    int64 `json:"bytes_out"`
	Active      int32 `json:"active"`
	Connections int64 `json:"connections"`
}

// service returns the counters of a destination, creating them on first use.
func (s *Stats) service(key string) *serviceCounters {
	s.servicesMu.Lock()
	defer s.servicesMu.Unlock()
	if s.services == nil {
		s.services = map[string]*serviceCounters{}
	}
	c, ok := s.services[key]
	if !ok {
		c = &serviceCounters{}
		s.services[key] = c
	}
	return c
}

func (c *serviceCounters) open()  { c.active.Add(1); c.connections.Add(1) }
func (c *serviceCounters) close() { c.active.Add(-1) }

// meter wraps the SSH channel of one connection so its bytes are counted:
// reads are traffic from the peer (in), writes traffic to the peer (out).
func (c *serviceCounters) meter(rwc io.ReadWriteCloser) io.ReadWriteCloser {
	return &meteredRWC{ReadWriteCloser: rwc, counters: c}
}

type meteredRWC struct {
	io.ReadWriteCloser
	counters *serviceCounters
}

func (m *meteredRWC) Read(b []byte) (int, error) {
	n, err := m.ReadWriteCloser.Read(b)
	if n > 0 {
		m.counters.bytesIn.Add(int64(n))
	}
	return n, err
}

func (m *meteredRWC) Write(b []byte) (int, error) {
	n, err := m.ReadWriteCloser.Write(b)
	if n > 0 {
		m.counters.bytesOut.Add(int64(n))
	}
	return n, err
}

// reverseKey marks a destination reached through a channel the server
// opened toward the connector.
const reverseKey = "<-"

func (s *Stats) servicesSnapshot() []ServiceStats {
	s.servicesMu.Lock()
	defer s.servicesMu.Unlock()
	out := make([]ServiceStats, 0, len(s.services))
	for key, c := range s.services {
		st := ServiceStats{Destination: key, BytesIn: c.bytesIn.Load(), BytesOut: c.bytesOut.Load(), Active: c.active.Load(), Connections: c.connections.Load()}
		if strings.HasPrefix(key, reverseKey) {
			st.Reverse = true
			st.Destination = strings.TrimPrefix(key, reverseKey)
		}
		out = append(out, st)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Destination < out[j].Destination })
	return out
}

// serviceStats implements sshTunnel for the inbound proxies (reverse binds).
func (t *Tunnel) serviceStats(key string) *serviceCounters {
	return t.stats.service(key)
}
