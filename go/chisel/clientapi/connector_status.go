package clientapi

import (
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
)

// Default source URL for the live connector_status map. Goes through the
// pfconnector-client loopback on port 22226, which tunnels the request to
// pfconnector-server's /api/v1/pfconnector/connector-status handler.
const defaultConnectorStatusURL = "http://localhost:22226/api/v1/pfconnector/connector-status"

// Default refresh interval for the connector_status cache. Live data — the
// prober on the server side runs at 2s, so anything in the same ballpark is
// fine. Overridable via PFCONNECTOR_STATUS_REFRESH_INTERVAL (seconds).
const defaultConnectorStatusRefreshInterval = 5 * time.Second

const connectorStatusFetchTimeout = 3 * time.Second

// connectorStatusPayload mirrors the JSON returned by
// GET /api/v1/pfconnector/connector-status.
type connectorStatusPayload struct {
	ConnectorStatus map[string]bool `json:"connector_status"`
}

// connectorStatusCache holds the most recent connector_id → up snapshot.
// Refresh runs in a background goroutine; reads are guarded by RLock.
//
// Mirrors the shape of multiDomainCache (same tunnel-gating, same poll
// pattern) so the two refreshers behave consistently when the local tunnel
// flaps. They could share a refresher loop, but separate caches keep the
// fast/slow cadences independent.
type connectorStatusCache struct {
	mu     sync.RWMutex
	status map[string]bool
	url    string
}

func newConnectorStatusCache(url string) *connectorStatusCache {
	if url == "" {
		url = defaultConnectorStatusURL
	}
	return &connectorStatusCache{url: url}
}

// get returns the most recent snapshot. Callers must treat a nil map as
// "unknown" rather than "all up".
func (c *connectorStatusCache) get() map[string]bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.status
}

// isUp reports whether the named connector was up at the last refresh.
// Returns ok=false when we have no observation yet (callers should default
// to whatever they'd do with no information — typically "remote").
func (c *connectorStatusCache) isUp(connectorID string) (up bool, ok bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if c.status == nil {
		return false, false
	}
	v, exists := c.status[connectorID]
	return v, exists
}

func (c *connectorStatusCache) set(next map[string]bool) {
	c.mu.Lock()
	c.status = next
	c.mu.Unlock()
}

func (c *connectorStatusCache) fetch(ctx context.Context) error {
	reqCtx, cancel := context.WithTimeout(ctx, connectorStatusFetchTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, c.url, nil)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("status %d: %s", resp.StatusCode, string(body))
	}
	payload := connectorStatusPayload{}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return fmt.Errorf("decode: %w", err)
	}
	if payload.ConnectorStatus == nil {
		payload.ConnectorStatus = map[string]bool{}
	}
	c.set(payload.ConnectorStatus)
	return nil
}

// startRefresher polls tunnel state and refreshes the connector status on a
// fast cadence whenever the local tunnel is up. While the tunnel is down it
// skips fetches (we wouldn't reach the server anyway) and clears the cache
// so callers don't act on stale data.
func (c *connectorStatusCache) startRefresher(ctx context.Context, tun tunnelState) {
	interval := defaultConnectorStatusRefreshInterval
	if v := os.Getenv("PFCONNECTOR_STATUS_REFRESH_INTERVAL"); v != "" {
		if secs, err := strconv.Atoi(v); err == nil && secs > 0 {
			interval = time.Duration(secs) * time.Second
		}
	}

	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		tick := func() {
			up := tun == nil || tun.IsActive()
			if !up {
				c.set(nil)
				return
			}
			if err := c.fetch(ctx); err != nil {
				log.Logger().Info(fmt.Sprintf("connector-status: fetch failed: %s", err))
			}
		}

		tick()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				tick()
			}
		}
	}()
}
