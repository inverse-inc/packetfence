package tunnel

import (
	"net"
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
