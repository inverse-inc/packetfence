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
	day0 := start.Format(uptimeDayLayout)
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
		map[string][]byte{day0: connectorDay}, map[string][]byte{day0: serverDay})

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

	// a day bucket takes its worst hour: one hour half down out of two
	day := 2 * time.Hour
	connectorTwoHours := make([]byte, offset+120)
	serverTwoHours := make([]byte, offset+120)
	for i := 0; i < 120; i++ {
		connectorTwoHours[offset+int64(i)] = 255
		serverTwoHours[offset+int64(i)] = 255
	}
	for i := 60; i < 90; i++ {
		connectorTwoHours[offset+int64(i)] = 0 // down while the server ran
	}
	h = computeUptime(start, start.Add(day), day, &start, map[string][]byte{day0: connectorTwoHours}, map[string][]byte{day0: serverTwoHours})
	if b := h.Buckets[0]; b.WorstAvailability == nil || math.Abs(*b.WorstAvailability-0.5) > 0.01 || math.Abs(*b.Availability-0.75) > 0.01 {
		t.Errorf("worst hour: availability %v worst %v, want 0.75 and 0.5", *b.Availability, b.WorstAvailability)
	}

	// never recorded: everything is no data
	h = computeUptime(start, end, 2*time.Minute, nil, nil, map[string][]byte{day0: serverDay})
	if h.Availability != nil || h.Buckets[0].Availability != nil || h.Buckets[0].NoDataMinutes != 2 {
		t.Errorf("never recorded connector: got %+v", h)
	}
}

func TestHAReportSamples(t *testing.T) {
	report := HAReport{Enabled: true, Hostname: "connector-a", Address: "192.0.2.1", State: "master", RadiusOK: true}
	report.Peers = append(report.Peers,
		struct {
			Hostname string `json:"hostname"`
			Address  string `json:"address"`
			Alive    bool   `json:"alive"`
			RadiusOK bool   `json:"radius_ok"`
		}{"connector-b", "192.0.2.2", true, false},
		struct {
			Hostname string `json:"hostname"`
			Address  string `json:"address"`
			Alive    bool   `json:"alive"`
			RadiusOK bool   `json:"radius_ok"`
		}{"connector-c", "192.0.2.3", false, false},
	)
	got := report.Samples()
	want := []HostSample{
		{"192.0.2.1", "connector-a", HostActive},
		{"192.0.2.2", "connector-b", HostStandbyRadiusDown},
		{"192.0.2.3", "connector-c", HostNotReporting},
	}
	if len(got) != len(want) {
		t.Fatalf("samples %+v, want %+v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("sample %d = %+v, want %+v", i, got[i], want[i])
		}
	}
	report.RadiusOK = false
	if s := report.Samples(); s[0].State != HostActiveRadiusDown {
		t.Errorf("active host with FreeRADIUS down: %+v", s[0])
	}
	if s := (HAReport{}).Samples(); s != nil {
		t.Errorf("HA off: %+v", s)
	}
}

func TestComputeHostBuckets(t *testing.T) {
	// 10:00 to 10:06 UTC, buckets of 2 minutes: active twice | standby, not
	// reporting | no data
	start := time.Date(2026, 10, 26, 10, 0, 0, 0, time.UTC)
	day := start.Format(uptimeDayLayout)
	offset := uptimeMinuteOffset(start)
	host := make([]byte, offset+5)
	host[offset+0] = HostActive
	host[offset+1] = HostActive
	host[offset+2] = HostStandby
	host[offset+3] = HostNotReporting
	got := computeHostBuckets(start, start.Add(6*time.Minute), 2*time.Minute, map[string][]byte{day: host})
	if len(got) != 3 {
		t.Fatalf("%d buckets, want 3", len(got))
	}
	if got[0].ActiveMinutes != 2 {
		t.Errorf("bucket 0: %+v", got[0])
	}
	if got[1].StandbyMinutes != 1 || got[1].NotReportingMinutes != 1 {
		t.Errorf("bucket 1: %+v", got[1])
	}
	if got[2].NoDataMinutes != 2 {
		t.Errorf("bucket 2: %+v", got[2])
	}
}
