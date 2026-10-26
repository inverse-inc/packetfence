package connector

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/redis/go-redis/v9"
)

// Tunnel uptime history of the connectors, for the admin UI strip charts.
//
// The pfconnector server holding a tunnel probes it every few seconds
// (chisel/server/connector_status.go) and, once a minute, writes one byte per
// connector for that minute in a per-day string (1440 bytes, UTC day):
//
//	pfconnector:uptime:<connector id>:<YYYYMMDD>
//
// 0 is "no sample" (no server held the tunnel), 1..255 the share of the
// probes that succeeded (1 = all failed, 255 = all succeeded). Every server
// also marks the minutes it was running in pfconnector:uptime-server:<YYYYMMDD>,
// so a minute without a connector sample reads as down when a server was up
// to see the tunnel missing, and as no data when none was. The first minute
// ever recorded for a connector is kept in pfconnector:uptime-since:<id>, the
// minutes before it are no data. Day keys expire after uptimeRetention.

const (
	uptimeKeyPrefix       = "pfconnector:uptime:"
	uptimeServerKeyPrefix = "pfconnector:uptime-server:"
	uptimeSinceKeyPrefix  = "pfconnector:uptime-since:"
	uptimeRetention       = 32 * 24 * time.Hour
	uptimeDayLayout       = "20060102"
	minutesPerDay         = 24 * 60
)

// UptimeSample is the probe count of a connector over one minute.
type UptimeSample struct {
	Up, Total int
}

func uptimeDayKey(prefix string, t time.Time) string {
	return prefix + t.UTC().Format(uptimeDayLayout)
}

func uptimeMinuteOffset(t time.Time) int64 {
	t = t.UTC()
	return int64(t.Hour()*60 + t.Minute())
}

// encodeUptime maps the share of successful probes to 1..255.
func encodeUptime(s UptimeSample) byte {
	if s.Total <= 0 {
		return 0
	}
	ratio := float64(s.Up) / float64(s.Total)
	return byte(1 + math.Round(254*math.Min(math.Max(ratio, 0), 1)))
}

// decodeUptime returns the share of successful probes of a sample byte.
func decodeUptime(b byte) float64 {
	return float64(b-1) / 254
}

// RecordUptimeMinute stores the samples of the given minute, and marks the
// minute as observed by a running server.
func RecordUptimeMinute(ctx context.Context, rdb *redis.Client, minute time.Time, samples map[string]UptimeSample) error {
	offset := uptimeMinuteOffset(minute)
	pipe := rdb.Pipeline()
	serverKey := uptimeDayKey(uptimeServerKeyPrefix, minute)
	pipe.SetRange(ctx, serverKey, offset, string([]byte{255}))
	pipe.Expire(ctx, serverKey, uptimeRetention)
	for id, sample := range samples {
		b := encodeUptime(sample)
		if b == 0 {
			continue
		}
		key := uptimeDayKey(uptimeKeyPrefix+id+":", minute)
		pipe.SetRange(ctx, key, offset, string([]byte{b}))
		pipe.Expire(ctx, key, uptimeRetention)
		pipe.SetNX(ctx, uptimeSinceKeyPrefix+id, minute.UTC().Unix(), 0)
	}
	_, err := pipe.Exec(ctx)
	return err
}

// UptimeWindows are the windows the admin UI asks for: their length and the
// size of each bucket.
var UptimeWindows = map[string]struct{ Length, Bucket time.Duration }{
	"1h":  {time.Hour, time.Minute},
	"24h": {24 * time.Hour, time.Hour},
	"30d": {30 * 24 * time.Hour, 24 * time.Hour},
}

// UptimeBucket sums the minutes of a bucket: up and down are fractional (a
// minute where half of the probes failed counts half up, half down).
type UptimeBucket struct {
	Start         time.Time `json:"start"`
	End           time.Time `json:"end"`
	UpMinutes     float64   `json:"up_minutes"`
	DownMinutes   float64   `json:"down_minutes"`
	NoDataMinutes int       `json:"no_data_minutes"`
	// nil when the bucket has no data at all
	Availability *float64 `json:"availability"`
}

type UptimeHistory struct {
	ConnectorID string     `json:"connector_id"`
	Window      string     `json:"window"`
	Since       *time.Time `json:"since"`
	GeneratedAt time.Time  `json:"generated_at"`
	UpMinutes   float64    `json:"up_minutes"`
	DownMinutes float64    `json:"down_minutes"`
	// nil when the window has no data at all
	Availability *float64       `json:"availability"`
	Buckets      []UptimeBucket `json:"buckets"`
}

func availability(up, down float64) *float64 {
	if up+down <= 0 {
		return nil
	}
	a := up / (up + down)
	return &a
}

// ReadUptime returns the uptime history of a connector over the given window
// (a key of UptimeWindows), in buckets ending at the last full minute.
func ReadUptime(ctx context.Context, connectorID, window string, now time.Time) (*UptimeHistory, error) {
	w, ok := UptimeWindows[window]
	if !ok {
		return nil, fmt.Errorf("unknown window %q", window)
	}
	end := now.UTC().Truncate(time.Minute)
	start := end.Add(-w.Length)

	var since *time.Time
	if v, err := redisClient.Get(ctx, uptimeSinceKeyPrefix+connectorID).Int64(); err == nil {
		t := time.Unix(v, 0).UTC()
		since = &t
	} else if err != redis.Nil {
		return nil, err
	}

	var days []time.Time
	for d := start.Truncate(24 * time.Hour); !d.After(end); d = d.Add(24 * time.Hour) {
		days = append(days, d)
	}
	keys := make([]string, 0, 2*len(days))
	for _, d := range days {
		keys = append(keys, uptimeDayKey(uptimeKeyPrefix+connectorID+":", d), uptimeDayKey(uptimeServerKeyPrefix, d))
	}
	values, err := redisClient.MGet(ctx, keys...).Result()
	if err != nil {
		return nil, err
	}
	connectorDays := map[string][]byte{}
	serverDays := map[string][]byte{}
	for i, d := range days {
		day := d.Format(uptimeDayLayout)
		if s, ok := values[2*i].(string); ok {
			connectorDays[day] = []byte(s)
		}
		if s, ok := values[2*i+1].(string); ok {
			serverDays[day] = []byte(s)
		}
	}

	history := computeUptime(start, end, w.Bucket, since, connectorDays, serverDays)
	history.ConnectorID = connectorID
	history.Window = window
	history.GeneratedAt = now
	return history, nil
}

// computeUptime buckets the minutes [start, end) from the per-day samples.
func computeUptime(start, end time.Time, bucket time.Duration, since *time.Time, connectorDays, serverDays map[string][]byte) *UptimeHistory {
	at := func(days map[string][]byte, m time.Time) byte {
		b := days[m.Format(uptimeDayLayout)]
		offset := uptimeMinuteOffset(m)
		if offset < int64(len(b)) {
			return b[offset]
		}
		return 0
	}

	history := &UptimeHistory{Since: since, Buckets: []UptimeBucket{}}
	for bStart := start; bStart.Before(end); bStart = bStart.Add(bucket) {
		b := UptimeBucket{Start: bStart, End: bStart.Add(bucket)}
		for m := bStart; m.Before(b.End); m = m.Add(time.Minute) {
			if since == nil || m.Before(*since) {
				b.NoDataMinutes++
				continue
			}
			if c := at(connectorDays, m); c != 0 {
				up := decodeUptime(c)
				b.UpMinutes += up
				b.DownMinutes += 1 - up
			} else if at(serverDays, m) != 0 {
				b.DownMinutes++
			} else {
				b.NoDataMinutes++
			}
		}
		b.Availability = availability(b.UpMinutes, b.DownMinutes)
		history.UpMinutes += b.UpMinutes
		history.DownMinutes += b.DownMinutes
		history.Buckets = append(history.Buckets, b)
	}
	history.Availability = availability(history.UpMinutes, history.DownMinutes)
	return history
}
