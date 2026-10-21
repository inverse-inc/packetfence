package clientapi

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// Default source URL for the cloud multi-domain config. Goes through the
// pfconnector-client loopback on port 22226, which tunnels the request to
// pfconnector-server's /api/v1/pfconnector/multi-domain-config handler.
const defaultMultiDomainConfigURL = "http://localhost:22226/api/v1/pfconnector/multi-domain-config"

// Default refresh interval for the cache. Can be overridden via the
// PFCONNECTOR_MULTI_DOMAIN_REFRESH_INTERVAL env var (seconds).
const defaultMultiDomainRefreshInterval = 300 * time.Second

const multiDomainFetchTimeout = 5 * time.Second

// multiDomainTunnelPollInterval is how often the refresher observes tunnel
// state to detect down→up transitions. Kept short and not env-gated — the
// check itself is cheap (a mutex-guarded pointer read). Declared as a var
// so tests can lower it for deterministic timing.
var multiDomainTunnelPollInterval = 5 * time.Second

// tunnelState is the subset of *tunnel.Tunnel the refresher needs. Declared
// locally so this file doesn't import the tunnel package and so tests can
// substitute a fake.
type tunnelState interface {
	IsActive() bool
}

// multiDomainConfig mirrors the JSON returned by
// GET /api/v1/pfconnector/multi-domain-config on pfconnector-server.
//
// DomainConnector maps domain_id → connector_id and is computed server-side
// from each domain's ad_server IP against connectors.conf network ranges.
// Used by radiusAuthorize (together with the live connector_status fed by
// connectorStatusCache) to short-circuit to "degraded" when the connector
// owning a realm's AD is unreachable.
type multiDomainConfig struct {
	Realms          map[string]multiDomainRealm  `json:"realms"`
	OrderedRealms   []string                     `json:"ordered_realms"`
	Domains         map[string]multiDomainDomain `json:"domains"`
	DomainConnector map[string]string            `json:"domain_connector"`
}

type multiDomainRealm struct {
	Regex  string `json:"regex"`
	Domain string `json:"domain"`
}

type multiDomainDomain struct {
	NtlmAuthHost string `json:"ntlm_auth_host"`
	NtlmAuthPort string `json:"ntlm_auth_port"`
	UseConnector string `json:"use_connector"`
}

// multiDomainCache holds a snapshot of the multi-domain config plus memoized
// compiled regexes for realms with a non-empty regex field. Refresh runs in
// a background goroutine; all reads are guarded by RLock.
type multiDomainCache struct {
	mu      sync.RWMutex
	cfg     *multiDomainConfig
	regexes map[string]*regexp.Regexp
	url     string
}

func newMultiDomainCache(url string) *multiDomainCache {
	if url == "" {
		url = defaultMultiDomainConfigURL
	}
	return &multiDomainCache{url: url}
}

// get returns the most recently fetched config, or nil if we've never
// succeeded in fetching.
func (c *multiDomainCache) get() (*multiDomainConfig, map[string]*regexp.Regexp) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.cfg, c.regexes
}

func (c *multiDomainCache) set(ctx context.Context, cfg *multiDomainConfig) {
	// Compile regexes outside the lock to minimize critical-section time.
	regexes := make(map[string]*regexp.Regexp, len(cfg.Realms))
	for key, realm := range cfg.Realms {
		if realm.Regex == "" {
			continue
		}
		re, err := regexp.Compile(realm.Regex)
		if err != nil {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("multi-domain: ignoring invalid regex for realm %q: %s", key, err))
			continue
		}
		regexes[key] = re
	}

	c.mu.Lock()
	c.cfg = cfg
	c.regexes = regexes
	c.mu.Unlock()
}

// fetch performs a single HTTP GET against the cloud multi-domain-config
// endpoint and replaces the cached snapshot on success.
func (c *multiDomainCache) fetch(ctx context.Context) error {
	reqCtx, cancel := context.WithTimeout(ctx, multiDomainFetchTimeout)
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
	cfg := multiDomainConfig{}
	if err := json.NewDecoder(resp.Body).Decode(&cfg); err != nil {
		return fmt.Errorf("decode: %w", err)
	}
	c.set(ctx, &cfg)
	return nil
}

// startRefresher polls tunnel state on a short interval and fetches the
// multi-domain config (a) immediately on a down→up transition, and (b) every
// `interval` while the tunnel stays up. While the tunnel is down it skips
// fetches entirely to avoid noisy logs and wasted HTTP timeouts.
//
// A nil `tun` is treated as "always up" so callers that don't care about
// tunnel state (e.g. tests) keep the old refresh-on-cadence behavior.
func (c *multiDomainCache) startRefresher(ctx context.Context, tun tunnelState) {
	interval := defaultMultiDomainRefreshInterval
	if v := os.Getenv("PFCONNECTOR_MULTI_DOMAIN_REFRESH_INTERVAL"); v != "" {
		if secs, err := strconv.Atoi(v); err == nil && secs > 0 {
			interval = time.Duration(secs) * time.Second
		}
	}

	go func() {
		ticker := time.NewTicker(multiDomainTunnelPollInterval)
		defer ticker.Stop()

		var wasUp bool
		var lastFetch time.Time

		tick := func() {
			up := tun == nil || tun.IsActive()
			if !up {
				wasUp = false
				return
			}
			transitionedUp := !wasUp
			wasUp = true
			if !transitionedUp && !lastFetch.IsZero() && time.Since(lastFetch) < interval {
				return
			}
			if err := c.fetch(ctx); err != nil {
				log.Logger().Info(fmt.Sprintf("multi-domain: fetch failed: %s", err))
				return
			}
			lastFetch = time.Now()
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
