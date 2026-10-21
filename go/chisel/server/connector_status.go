package chserver

import (
	"bufio"
	"context"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
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
	defaultConnectorStatusInterval = 2 * time.Second
	defaultConnectorStatusTimeout  = 1 * time.Second
	connectorStatusProbeConcurrency = 32
)

// ConnectorStatusTracker maintains a connector_id -> up/down map refreshed
// by a periodic /ping over each active chisel tunnel. Reads are guarded by
// an RWMutex so the multi-domain handler can snapshot cheaply.
type ConnectorStatusTracker struct {
	mu     sync.RWMutex
	status map[string]bool
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

// Start kicks off the background prober. It exits when ctx is done.
func (t *ConnectorStatusTracker) Start(ctx context.Context) {
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
