package chserver

import (
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
)

func snap(in, out int64, services ...tunnel.ServiceStats) tunnel.StatsSnapshot {
	return tunnel.StatsSnapshot{BytesIn: in, BytesOut: out, Services: services}
}

// Rates come from consecutive cumulative samples; a counter that goes
// backwards (tunnel replaced) counts as bytes since the new tunnel started;
// the window keeps one sample before the cutoff; services are aligned.
func TestTrafficHistorySeries(t *testing.T) {
	h := &trafficHistory{byConnector: map[string][]trafficSample{}}
	t0 := time.Unix(1_700_000_000, 0)
	radius := func(in, out int64) tunnel.ServiceStats {
		return tunnel.ServiceStats{Destination: "10.0.0.1:1812/udp|radius", BytesIn: in, BytesOut: out}
	}
	collector := func(out int64) tunnel.ServiceStats {
		return tunnel.ServiceStats{Destination: "127.0.0.1:4723", Reverse: true, BytesOut: out}
	}
	h.record("c1", t0, snap(1000, 500, radius(100, 50)))
	h.record("c1", t0.Add(5*time.Second), snap(1500, 600, radius(200, 60), collector(30)))
	h.record("c1", t0.Add(10*time.Second), snap(200, 100, radius(20, 10), collector(90))) // tunnel replaced
	h.record("c1", t0.Add(15*time.Second), snap(700, 100, radius(120, 10), collector(90)))

	s := h.series("c1", 12*time.Second, t0.Add(15*time.Second))
	if s == nil {
		t.Fatal("no series")
	}
	// cutoff = t0+3s: samples from t0+0 (kept as the previous point) on.
	if len(s.T) != 3 || s.T[0] != t0.Add(5*time.Second).Unix() {
		t.Fatalf("T = %v", s.T)
	}
	want := []float64{100, 40, 100} // (1500-1000)/5, reset -> 200/5, (700-200)/5
	for i, v := range want {
		if s.In[i] != v {
			t.Errorf("In[%d] = %v, want %v", i, s.In[i], v)
		}
	}
	if s.Out[0] != 20 || s.Out[1] != 20 || s.Out[2] != 0 {
		t.Errorf("Out = %v", s.Out)
	}
	r := s.Services["10.0.0.1:1812/udp|radius"]
	if r == nil || r.Reverse || len(r.In) != 3 || r.In[0] != 20 || r.In[1] != 4 || r.In[2] != 20 {
		t.Errorf("radius series = %+v", r)
	}
	c := s.Services["127.0.0.1:4723"]
	if c == nil || !c.Reverse || c.Out[0] != 6 || c.Out[1] != 12 || c.Out[2] != 0 {
		t.Errorf("collector series = %+v", c)
	}

	if h.series("c1", 2*time.Second, t0.Add(15*time.Second)) == nil {
		t.Error("a 2s window still has the last two samples")
	}
	if h.series("unknown", time.Hour, t0) != nil {
		t.Error("unknown connector must have no series")
	}
}

func TestTrafficHistoryCapacityAndEviction(t *testing.T) {
	h := &trafficHistory{byConnector: map[string][]trafficSample{}}
	t0 := time.Unix(1_700_000_000, 0)
	for i := 0; i < trafficHistoryCapacity+10; i++ {
		h.record("c1", t0.Add(time.Duration(i)*trafficSampleInterval), snap(int64(i), 0))
	}
	if n := len(h.byConnector["c1"]); n != trafficHistoryCapacity {
		t.Fatalf("kept %d samples, want %d", n, trafficHistoryCapacity)
	}
	h.record("old", t0, snap(1, 1))
	h.sampleAll(t0.Add(trafficHistoryRetention + time.Minute))
	if _, ok := h.byConnector["old"]; ok {
		t.Error("connector not sampled for the whole retention must be evicted")
	}
}
