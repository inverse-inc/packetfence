package connector

import (
	"context"
	"fmt"
	"math"
	"sort"
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
	// per host of an HA connector: <id>:<host address>:<YYYYMMDD>, one Host*
	// state byte per minute, and the hostname of each address (hash <id>)
	uptimeHostKeyPrefix   = "pfconnector:uptime-host:"
	uptimeHostsKeyPrefix  = "pfconnector:uptime-hosts:"
	uptimeKeyPrefix       = "pfconnector:uptime:"
	uptimeServerKeyPrefix = "pfconnector:uptime-server:"
	uptimeSinceKeyPrefix  = "pfconnector:uptime-since:"
	uptimeRetention       = 32 * 24 * time.Hour
	uptimeDayLayout       = "20060102"
	minutesPerDay         = 24 * 60
)

// The state of a host of an HA connector over a minute, as reported by the
// active host (0: no report).
const (
	HostNotReporting      byte = 1
	HostStandbyRadiusDown byte = 2
	HostStandby           byte = 3
	HostActiveRadiusDown  byte = 4
	HostActive            byte = 5
)

// HostSample is the state of one host of an HA connector at a minute.
type HostSample struct {
	Address, Hostname string
	State             byte
}

// HAReport is the part of the HA status of a connector-remote (its
// /api/v1/ha/status) the per-host history is made of.
type HAReport struct {
	Enabled  bool   `json:"enabled"`
	Hostname string `json:"hostname"`
	Address  string `json:"address"`
	State    string `json:"state"`
	RadiusOK bool   `json:"radius_ok"`
	Peers    []struct {
		Hostname string `json:"hostname"`
		Address  string `json:"address"`
		Alive    bool   `json:"alive"`
		RadiusOK bool   `json:"radius_ok"`
	} `json:"peers"`
}

// Samples returns the state of every host of the report: the reporting host
// holds the tunnel (it is the active one), the peers stand by.
func (r HAReport) Samples() []HostSample {
	if !r.Enabled || r.Address == "" {
		return nil
	}
	active := HostActive
	if !r.RadiusOK {
		active = HostActiveRadiusDown
	}
	samples := []HostSample{{Address: r.Address, Hostname: r.Hostname, State: active}}
	for _, p := range r.Peers {
		if p.Address == "" {
			continue
		}
		state := HostStandby
		switch {
		case !p.Alive:
			state = HostNotReporting
		case !p.RadiusOK:
			state = HostStandbyRadiusDown
		}
		samples = append(samples, HostSample{Address: p.Address, Hostname: p.Hostname, State: state})
	}
	return samples
}

// RecordHostsMinute stores the state of the hosts of an HA connector at the
// given minute.
func RecordHostsMinute(ctx context.Context, rdb *redis.Client, minute time.Time, connectorID string, samples []HostSample) error {
	if len(samples) == 0 {
		return nil
	}
	offset := uptimeMinuteOffset(minute)
	hostsKey := uptimeHostsKeyPrefix + connectorID
	pipe := rdb.Pipeline()
	for _, s := range samples {
		key := uptimeDayKey(uptimeHostKeyPrefix+connectorID+":"+s.Address+":", minute)
		pipe.SetRange(ctx, key, offset, string([]byte{s.State}))
		pipe.Expire(ctx, key, uptimeRetention)
		pipe.HSet(ctx, hostsKey, s.Address, s.Hostname)
	}
	pipe.Expire(ctx, hostsKey, uptimeRetention)
	_, err := pipe.Exec(ctx)
	return err
}

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
	// the availability of its worst hour, for a bucket longer than an hour
	// (a day takes the colour of its worst hour); its availability otherwise
	WorstAvailability *float64 `json:"worst_availability"`
	// the first minute with downtime, nil without any
	FirstDown *time.Time `json:"first_down"`
}

// HostBucket counts the minutes a host of an HA connector spent in each state
// over a bucket.
type HostBucket struct {
	Start               time.Time `json:"start"`
	End                 time.Time `json:"end"`
	ActiveMinutes       int       `json:"active_minutes"`
	ActiveRadiusDown    int       `json:"active_radius_down_minutes"`
	StandbyMinutes      int       `json:"standby_minutes"`
	StandbyRadiusDown   int       `json:"standby_radius_down_minutes"`
	NotReportingMinutes int       `json:"not_reporting_minutes"`
	NoDataMinutes       int       `json:"no_data_minutes"`
}

// HostUptime is the history of one host of an HA connector.
type HostUptime struct {
	Address  string       `json:"address"`
	Hostname string       `json:"hostname"`
	Buckets  []HostBucket `json:"buckets"`
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
	// the hosts of an HA connector, empty otherwise
	Hosts []HostUptime `json:"hosts"`
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
	if history.Hosts, err = readHostsUptime(ctx, connectorID, start, end, w.Bucket, days); err != nil {
		return nil, err
	}
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
		// up and down minutes of each hour of the bucket
		hours := map[int64]*[2]float64{}
		for m := bStart; m.Before(b.End); m = m.Add(time.Minute) {
			if since == nil || m.Before(*since) {
				b.NoDataMinutes++
				continue
			}
			up, down := 0.0, 0.0
			if c := at(connectorDays, m); c != 0 {
				up = decodeUptime(c)
				down = 1 - up
			} else if at(serverDays, m) != 0 {
				down = 1
			} else {
				b.NoDataMinutes++
				continue
			}
			b.UpMinutes += up
			b.DownMinutes += down
			if down > 0 && b.FirstDown == nil {
				first := m
				b.FirstDown = &first
			}
			hour := int64(m.Sub(bStart) / time.Hour)
			if hours[hour] == nil {
				hours[hour] = &[2]float64{}
			}
			hours[hour][0] += up
			hours[hour][1] += down
		}
		b.Availability = availability(b.UpMinutes, b.DownMinutes)
		b.WorstAvailability = b.Availability
		if bucket > time.Hour {
			for _, h := range hours {
				if a := availability(h[0], h[1]); a != nil && (b.WorstAvailability == nil || *a < *b.WorstAvailability) {
					b.WorstAvailability = a
				}
			}
		}
		history.UpMinutes += b.UpMinutes
		history.DownMinutes += b.DownMinutes
		history.Buckets = append(history.Buckets, b)
	}
	history.Availability = availability(history.UpMinutes, history.DownMinutes)
	return history
}

// readHostsUptime reads the history of the hosts of an HA connector.
func readHostsUptime(ctx context.Context, connectorID string, start, end time.Time, bucket time.Duration, days []time.Time) ([]HostUptime, error) {
	hosts, err := redisClient.HGetAll(ctx, uptimeHostsKeyPrefix+connectorID).Result()
	if err != nil && err != redis.Nil {
		return nil, err
	}
	addresses := make([]string, 0, len(hosts))
	for address := range hosts {
		addresses = append(addresses, address)
	}
	sort.Strings(addresses)
	result := []HostUptime{}
	for _, address := range addresses {
		keys := make([]string, 0, len(days))
		for _, d := range days {
			keys = append(keys, uptimeDayKey(uptimeHostKeyPrefix+connectorID+":"+address+":", d))
		}
		values, err := redisClient.MGet(ctx, keys...).Result()
		if err != nil {
			return nil, err
		}
		hostDays := map[string][]byte{}
		for i, d := range days {
			if s, ok := values[i].(string); ok {
				hostDays[d.Format(uptimeDayLayout)] = []byte(s)
			}
		}
		result = append(result, HostUptime{
			Address:  address,
			Hostname: hosts[address],
			Buckets:  computeHostBuckets(start, end, bucket, hostDays),
		})
	}
	return result, nil
}

// computeHostBuckets counts the minutes [start, end) of each host state.
func computeHostBuckets(start, end time.Time, bucket time.Duration, hostDays map[string][]byte) []HostBucket {
	buckets := []HostBucket{}
	for bStart := start; bStart.Before(end); bStart = bStart.Add(bucket) {
		b := HostBucket{Start: bStart, End: bStart.Add(bucket)}
		for m := bStart; m.Before(b.End); m = m.Add(time.Minute) {
			day := hostDays[m.Format(uptimeDayLayout)]
			state := byte(0)
			if offset := uptimeMinuteOffset(m); offset < int64(len(day)) {
				state = day[offset]
			}
			switch state {
			case HostActive:
				b.ActiveMinutes++
			case HostActiveRadiusDown:
				b.ActiveRadiusDown++
			case HostStandby:
				b.StandbyMinutes++
			case HostStandbyRadiusDown:
				b.StandbyRadiusDown++
			case HostNotReporting:
				b.NotReportingMinutes++
			default:
				b.NoDataMinutes++
			}
		}
		buckets = append(buckets, b)
	}
	return buckets
}
