package connector

import (
	"math"
	"testing"
	"time"
)

func TestUptimeEncoding(t *testing.T) {
	if b := encodeUptime(UptimeSample{}); b != 0 {
		t.Errorf("no probe encoded as %d, want 0", b)
	}
	for _, test := range []struct {
		sample UptimeSample
		want   byte
	}{
		{UptimeSample{Up: 0, Total: 30}, 1},
		{UptimeSample{Up: 30, Total: 30}, 255},
		{UptimeSample{Up: 15, Total: 30}, 128},
	} {
		b := encodeUptime(test.sample)
		if b != test.want {
			t.Errorf("%+v encoded as %d, want %d", test.sample, b, test.want)
		}
		if got, want := decodeUptime(b), float64(test.sample.Up)/float64(test.sample.Total); math.Abs(got-want) > 0.005 {
			t.Errorf("%d decoded as %f, want %f", b, got, want)
		}
	}
}

func TestComputeUptime(t *testing.T) {
	// 10:00 to 10:06 UTC, buckets of 2 minutes
	start := time.Date(2026, 10, 26, 10, 0, 0, 0, time.UTC)
	end := start.Add(6 * time.Minute)
	since := start.Add(time.Minute)
	day := start.Format(uptimeDayLayout)
	offset := uptimeMinuteOffset(start)

	connectorDay := make([]byte, offset+6)
	serverDay := make([]byte, offset+6)
	for i := 0; i < 5; i++ {
		serverDay[offset+int64(i)] = 255
	}
	connectorDay[offset+0] = 255 // before since: no data
	connectorDay[offset+1] = 255 // up
	connectorDay[offset+2] = 128 // half up
	// 10:03, 10:04: no connector sample, server up: down
	// 10:05: no sample at all: no data

	h := computeUptime(start, end, 2*time.Minute, &since,
		map[string][]byte{day: connectorDay}, map[string][]byte{day: serverDay})

	if len(h.Buckets) != 3 {
		t.Fatalf("got %d buckets, want 3", len(h.Buckets))
	}
	for i, want := range []struct {
		up, down float64
		noData   int
	}{
		{1, 0, 1},
		{0.5, 1.5, 0},
		{0, 1, 1},
	} {
		b := h.Buckets[i]
		if math.Abs(b.UpMinutes-want.up) > 0.01 || math.Abs(b.DownMinutes-want.down) > 0.01 || b.NoDataMinutes != want.noData {
			t.Errorf("bucket %d: got up %f down %f no data %d, want %+v", i, b.UpMinutes, b.DownMinutes, b.NoDataMinutes, want)
		}
	}
	if h.Availability == nil || math.Abs(*h.Availability-1.5/4) > 0.01 {
		t.Errorf("availability %v, want %f", h.Availability, 1.5/4)
	}

	// never recorded: everything is no data
	h = computeUptime(start, end, 2*time.Minute, nil, nil, map[string][]byte{day: serverDay})
	if h.Availability != nil || h.Buckets[0].Availability != nil || h.Buckets[0].NoDataMinutes != 2 {
		t.Errorf("never recorded connector: got %+v", h)
	}
}
