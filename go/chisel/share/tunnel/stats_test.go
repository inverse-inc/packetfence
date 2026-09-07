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
