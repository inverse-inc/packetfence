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

// multiDomainConfig mirrors the JSON returned by
// GET /api/v1/pfconnector/multi-domain-config on pfconnector-server.
type multiDomainConfig struct {
	Realms        map[string]multiDomainRealm  `json:"realms"`
	OrderedRealms []string                     `json:"ordered_realms"`
	Domains       map[string]multiDomainDomain `json:"domains"`
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

// startRefresher kicks off a best-effort first fetch and then refreshes on a
// fixed interval until ctx is cancelled.
func (c *multiDomainCache) startRefresher(ctx context.Context) {
	interval := defaultMultiDomainRefreshInterval
	if v := os.Getenv("PFCONNECTOR_MULTI_DOMAIN_REFRESH_INTERVAL"); v != "" {
		if secs, err := strconv.Atoi(v); err == nil && secs > 0 {
			interval = time.Duration(secs) * time.Second
		}
	}

	go func() {
		if err := c.fetch(ctx); err != nil {
			log.Logger().Info(fmt.Sprintf("multi-domain: initial fetch failed (will retry): %s", err))
		}
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if err := c.fetch(ctx); err != nil {
					log.Logger().Info(fmt.Sprintf("multi-domain: refresh failed: %s", err))
				}
			}
		}
	}()
}
