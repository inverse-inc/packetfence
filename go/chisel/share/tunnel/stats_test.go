package tunnel

import (
	"net"
	"testing"
	"time"
)

func TestStatsMeterAndSnapshot(t *testing.T) {
	s := NewStats()
	a, b := net.Pipe()
	defer a.Close()
	defer b.Close()
	metered := s.MeterConn(a)

	go func() {
		buf := make([]byte, 64)
		b.Read(buf)
		b.Write([]byte("pong!"))
	}()
	if _, err := metered.Write([]byte("ping")); err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, 64)
	n, err := metered.Read(buf)
	if err != nil || n != 5 {
		t.Fatalf("read %d, %v", n, err)
	}
	s.recordRTT(12 * time.Millisecond)
	s.connected(time.Unix(1_700_000_000, 0))

	snap := s.snapshot(3)
	if snap.BytesOut != 4 || snap.BytesIn != 5 {
		t.Errorf("bytes in/out = %d/%d, want 5/4", snap.BytesIn, snap.BytesOut)
	}
	if snap.RTTMs != 12 || snap.Pings != 1 {
		t.Errorf("rtt=%v pings=%d", snap.RTTMs, snap.Pings)
	}
	if snap.Channels != 3 || snap.ConnectedAt == nil || snap.ConnectedAt.Unix() != 1_700_000_000 {
		t.Errorf("channels=%d connected_at=%v", snap.Channels, snap.ConnectedAt)
	}
	if NewStats().snapshot(0).ConnectedAt != nil {
		t.Error("never-connected stats must not report connected_at")
	}
}

type rwcBuffer struct {
	in  []byte
	out []byte
}

func (b *rwcBuffer) Read(p []byte) (int, error)  { n := copy(p, b.in); b.in = b.in[n:]; return n, nil }
func (b *rwcBuffer) Write(p []byte) (int, error) { b.out = append(b.out, p...); return len(p), nil }
func (b *rwcBuffer) Close() error                { return nil }

// Channels are counted per destination, in both directions, and the
// snapshot lists them sorted with reverse channels flagged.
func TestStatsPerService(t *testing.T) {
	s := NewStats()
	radius := s.service(serviceKey("10.0.0.1:1812", "udp", "radius"))
	radius.open()
	stream := radius.meter(&rwcBuffer{in: []byte("hello")})
	buf := make([]byte, 16)
	stream.Read(buf)
	stream.Write([]byte("ok"))
	radius.close()

	collector := s.service(reverseKey + "127.0.0.1:4723")
	collector.open()
	collector.meter(&rwcBuffer{}).Write([]byte("abc"))

	snap := s.snapshot(1)
	if len(snap.Services) != 2 {
		t.Fatalf("services = %+v", snap.Services)
	}
	if snap.Services[0].Destination != "10.0.0.1:1812/udp|radius" || snap.Services[0].BytesIn != 5 || snap.Services[0].BytesOut != 2 || snap.Services[0].Active != 0 || snap.Services[0].Connections != 1 || snap.Services[0].Reverse {
		t.Errorf("radius service = %+v", snap.Services[0])
	}
	if snap.Services[1].Destination != "127.0.0.1:4723" || !snap.Services[1].Reverse || snap.Services[1].BytesOut != 3 || snap.Services[1].Active != 1 {
		t.Errorf("collector service = %+v", snap.Services[1])
	}
	if serviceKey("host:80", "", "") != "host:80" || serviceKey("host:80", "tcp", "proxyproto") != "host:80/tcp|proxyproto" {
		t.Error("serviceKey format")
	}
}
