package chserver

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/redis/go-redis/v9"
)

// connectorStatusProbeTarget is the address we ask the chisel-client to
// dial through the SSH session — same target the credcache forward uses,
// because the pfconnector-client API listens on :8081 (see go/chisel/main.go).
const connectorStatusProbeTarget = "127.0.0.1:8081"

// connectorStatusProbePath is the localhost-only ping endpoint exposed by
// the pfconnector-client API (clientapi.client_api setupRoutes).
const connectorStatusProbePath = "/api/v1/service/ping"

// Default cadence and timeouts for the connector status prober. Both are
// overridable via env vars so deployments can tune without a rebuild.
const (
	defaultConnectorStatusInterval  = 2 * time.Second
	defaultConnectorStatusTimeout   = 1 * time.Second
	connectorStatusProbeConcurrency = 32
)

// ConnectorStatusTracker maintains a connector_id -> up/down map refreshed
// by a periodic /ping over each active chisel tunnel. Reads are guarded by
// an RWMutex so the multi-domain handler can snapshot cheaply.
type ConnectorStatusTracker struct {
	mu     sync.RWMutex
	status map[string]bool

	// the server starts once per listening address: one prober only
	start sync.Once

	// probe counts of the current minute, written to the uptime history
	// (connector/uptime.go) when the minute is over
	minute  time.Time
	ticks   int
	samples map[string]connector.UptimeSample
}

// NewConnectorStatusTracker returns an empty tracker.
func NewConnectorStatusTracker() *ConnectorStatusTracker {
	return &ConnectorStatusTracker{status: map[string]bool{}}
}

// Snapshot returns a copy of the current status map. Always non-nil.
func (t *ConnectorStatusTracker) Snapshot() map[string]bool {
	t.mu.RLock()
	defer t.mu.RUnlock()
	out := make(map[string]bool, len(t.status))
	for k, v := range t.status {
		out[k] = v
	}
	return out
}

// IsUp returns true only if the tracker has positively observed the
// connector as reachable on its last probe.
func (t *ConnectorStatusTracker) IsUp(connectorID string) bool {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.status[connectorID]
}

func (t *ConnectorStatusTracker) replace(next map[string]bool) {
	t.mu.Lock()
	t.status = next
	t.mu.Unlock()
}

// Start kicks off the background prober, on the first call only. It exits
// when ctx is done. rdb receives the uptime history, nil to keep none.
func (t *ConnectorStatusTracker) Start(ctx context.Context, rdb *redis.Client) {
	t.start.Do(func() { t.run(ctx, rdb) })
}

func (t *ConnectorStatusTracker) run(ctx context.Context, rdb *redis.Client) {
	interval := envDuration("PFCONNECTOR_STATUS_PROBE_INTERVAL", defaultConnectorStatusInterval)
	timeout := envDuration("PFCONNECTOR_STATUS_PROBE_TIMEOUT", defaultConnectorStatusTimeout)

	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		t.tick(ctx, timeout)
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				t.tick(ctx, timeout)
				if rdb != nil {
					t.recordUptime(ctx, rdb, time.Now())
				}
			}
		}
	}()
}

// tick walks every entry in activeTunnels, probes each in parallel, and
// atomically replaces the status map. Connectors whose tunnel is not active
// are recorded as down without an actual probe.
func (t *ConnectorStatusTracker) tick(ctx context.Context, timeout time.Duration) {
	type job struct {
		id  string
		tun *tunnel.Tunnel
	}
	var jobs []job
	activeTunnels.Range(func(k, v any) bool {
		id, ok := k.(string)
		if !ok {
			return true
		}
		tun, ok := v.(*tunnel.Tunnel)
		if !ok {
			return true
		}
		jobs = append(jobs, job{id: id, tun: tun})
		return true
	})

	results := make(map[string]bool, len(jobs))
	var mu sync.Mutex
	sem := make(chan struct{}, connectorStatusProbeConcurrency)
	var wg sync.WaitGroup

	for _, j := range jobs {
		if !j.tun.IsActive() {
			mu.Lock()
			results[j.id] = false
			mu.Unlock()
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func(id string, tun *tunnel.Tunnel) {
			defer wg.Done()
			defer func() { <-sem }()
			up := probeConnector(ctx, tun, timeout)
			mu.Lock()
			results[id] = up
			mu.Unlock()
		}(j.id, j.tun)
	}
	wg.Wait()
	t.replace(results)
}

// recordUptime adds the last probe results to the counts of the current
// minute and, on the first tick of a new minute, writes the previous one.
// The minute the prober started in is partial and not written. The ticks a
// connector missed in a minute (tunnel down or held by another server) count
// as failed probes.
func (t *ConnectorStatusTracker) recordUptime(ctx context.Context, rdb *redis.Client, now time.Time) {
	minute := now.Truncate(time.Minute)
	if !minute.Equal(t.minute) {
		if !t.minute.IsZero() && t.samples != nil {
			for id, sample := range t.samples {
				if sample.Total < t.ticks {
					sample.Total = t.ticks
					t.samples[id] = sample
				}
			}
			wctx, cancel := context.WithTimeout(ctx, 2*time.Second)
			if err := connector.RecordUptimeMinute(wctx, rdb, t.minute, t.samples); err != nil {
				log.LoggerWContext(ctx).Warn(fmt.Sprintf("connector-status: unable to record the uptime of %s: %s", t.minute.Format(time.RFC3339), err))
			}
			cancel()
			// the hosts of the HA connectors, asked through their tunnel: in
			// the background, not to hold the prober
			go recordHostsMinute(ctx, rdb, t.minute)
		}
		started := !t.minute.IsZero()
		t.minute = minute
		t.ticks = 0
		t.samples = nil
		if started {
			t.samples = map[string]connector.UptimeSample{}
		}
	}
	if t.samples == nil {
		return
	}
	t.ticks++
	for id, up := range t.Snapshot() {
		sample := t.samples[id]
		sample.Total++
		if up {
			sample.Up++
		}
		t.samples[id] = sample
	}
}

// connectorHAStatusPath is the HA status of the connector-remote hosts
// (clientapi haStatusHandler), absent on the connectors predating it.
const connectorHAStatusPath = "/api/v1/ha/status"

// recordHostsMinute records the state of the hosts of every HA connector
// whose tunnel this server holds, for the per-host uptime history.
func recordHostsMinute(ctx context.Context, rdb *redis.Client, minute time.Time) {
	var wg sync.WaitGroup
	sem := make(chan struct{}, connectorStatusProbeConcurrency)
	activeTunnels.Range(func(k, v any) bool {
		id, ok := k.(string)
		tun, ok2 := v.(*tunnel.Tunnel)
		if !ok || !ok2 || !tun.IsActive() {
			return true
		}
		wg.Add(1)
		sem <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-sem }()
			cctx, cancel := context.WithTimeout(ctx, 3*time.Second)
			defer cancel()
			status, body, err := tunnelGet(cctx, tun, connectorHAStatusPath)
			if err != nil || status != http.StatusOK {
				return
			}
			report := connector.HAReport{}
			if json.Unmarshal(body, &report) != nil {
				return
			}
			if err := connector.RecordHostsMinute(cctx, rdb, minute, id, report.Samples()); err != nil {
				log.LoggerWContext(ctx).Warn(fmt.Sprintf("connector-status: unable to record the hosts of %s: %s", id, err))
			}
		}()
		return true
	})
	wg.Wait()
}

// tunnelGet sends a GET for path to the connector-remote API through the
// tunnel, and returns the status and body of the reply.
func tunnelGet(ctx context.Context, tun *tunnel.Tunnel, path string) (int, []byte, error) {
	return tunnelRequest(ctx, tun, http.MethodGet, path, nil)
}

// tunnelRequest sends one HTTP request (a JSON body when body is not nil) to
// the connector-remote API through the tunnel, and returns the status and
// body of the reply.
func tunnelRequest(ctx context.Context, tun *tunnel.Tunnel, method, path string, body []byte) (int, []byte, error) {
	ch, err := tun.OpenChiselChannel(ctx, connectorStatusProbeTarget)
	if err != nil {
		return 0, nil, err
	}
	defer ch.Close()
	type result struct {
		status int
		body   []byte
		err    error
	}
	done := make(chan result, 1)
	go func() {
		var reader io.Reader
		if body != nil {
			reader = bytes.NewReader(body)
		}
		req, err := http.NewRequest(method, "http://"+connectorStatusProbeTarget+path, reader)
		if err != nil {
			done <- result{err: err}
			return
		}
		req.Host = connectorStatusProbeTarget
		req.Close = true
		req.Header.Set("User-Agent", "pfconnector-status-probe")
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		if err := req.Write(ch); err != nil {
			done <- result{err: err}
			return
		}
		resp, err := http.ReadResponse(bufio.NewReader(ch), req)
		if err != nil {
			done <- result{err: err}
			return
		}
		defer resp.Body.Close()
		body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		done <- result{status: resp.StatusCode, body: body, err: err}
	}()
	select {
	case r := <-done:
		return r.status, r.body, r.err
	case <-ctx.Done():
		return 0, nil, ctx.Err()
	}
}

// probeConnector opens a chisel SSH channel to the client's local API,
// writes a minimal HTTP/1.1 GET /api/v1/service/ping, and returns true
// only on a 2xx response within timeout.
func probeConnector(ctx context.Context, tun *tunnel.Tunnel, timeout time.Duration) bool {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	ch, err := tun.OpenChiselChannel(ctx, connectorStatusProbeTarget)
	if err != nil {
		return false
	}
	defer ch.Close()

	done := make(chan bool, 1)
	go func() {
		req, err := http.NewRequest(http.MethodGet, "http://"+connectorStatusProbeTarget+connectorStatusProbePath, nil)
		if err != nil {
			done <- false
			return
		}
		req.Host = connectorStatusProbeTarget
		req.Close = true
		req.Header.Set("User-Agent", "pfconnector-status-probe")
		if err := req.Write(ch); err != nil {
			done <- false
			return
		}
		resp, err := http.ReadResponse(bufio.NewReader(ch), req)
		if err != nil {
			done <- false
			return
		}
		defer resp.Body.Close()
		done <- resp.StatusCode >= 200 && resp.StatusCode < 300
	}()

	select {
	case ok := <-done:
		return ok
	case <-ctx.Done():
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("connector-status: probe timed out after %s", timeout))
		return false
	}
}

// envDuration reads an int seconds env var, returning the fallback on any
// parse failure or non-positive value.
func envDuration(key string, fallback time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	secs, err := strconv.Atoi(v)
	if err != nil || secs <= 0 {
		return fallback
	}
	return time.Duration(secs) * time.Second
}
