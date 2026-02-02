package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// HealthChecker periodically checks the health of backends by making
// HTTPS requests to fingerbank-collector.
type HealthChecker struct {
	config     *ProxyConfig
	lb         *LoadBalancer
	httpClient *http.Client
}

// NewHealthChecker creates a new health checker.
func NewHealthChecker(config *ProxyConfig, lb *LoadBalancer) *HealthChecker {
	// Create HTTP client with TLS config that skips certificate verification
	// (fingerbank-collector uses self-signed certificates)
	transport := &http.Transport{
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
		TLSHandshakeTimeout: 5 * time.Second,
	}

	httpClient := &http.Client{
		Transport: transport,
		Timeout:   config.HealthCheckTimeout,
		// Don't follow redirects
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	return &HealthChecker{
		config:     config,
		lb:         lb,
		httpClient: httpClient,
	}
}

// Start begins the health checking loop.
func (hc *HealthChecker) Start(ctx context.Context) {
	log.LoggerWContext(ctx).Info("Starting health checker")

	// Do an initial health check immediately
	hc.checkAllBackends(ctx)

	ticker := time.NewTicker(hc.config.HealthCheckInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.LoggerWContext(ctx).Info("Health checker stopped")
			return
		case <-ticker.C:
			hc.checkAllBackends(ctx)
		}
	}
}

// checkAllBackends checks the health of all backends in parallel.
func (hc *HealthChecker) checkAllBackends(ctx context.Context) {
	backends := hc.lb.GetAllBackends()
	if len(backends) == 0 {
		log.LoggerWContext(ctx).Warn("No backends to check")
		return
	}

	log.LoggerWContext(ctx).Debug(fmt.Sprintf("Running health checks for %d backends", len(backends)))

	var wg sync.WaitGroup
	for _, backend := range backends {
		wg.Add(1)
		go func(b *Backend) {
			defer wg.Done()
			hc.checkBackend(ctx, b)
		}(backend)
	}
	wg.Wait()

	// Log current primary after health checks
	primary := hc.lb.GetPrimary()
	if primary != nil {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Current primary backend: %s (%s)", primary.Host, primary.ManagementIP))
	} else {
		log.LoggerWContext(ctx).Warn("No healthy backend available after health checks")
	}
}

// checkBackend checks the health of a single backend.
func (hc *HealthChecker) checkBackend(ctx context.Context, backend *Backend) {
	url := fmt.Sprintf("https://%s:%d%s",
		backend.ManagementIP,
		hc.config.HealthCheckPort,
		hc.config.HealthCheckPath,
	)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to create health check request for %s: %s",
			backend.Host, err.Error()))
		hc.lb.SetHealth(backend.Host, false)
		return
	}

	resp, err := hc.httpClient.Do(req)
	if err != nil {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Health check failed for %s: %s",
			backend.Host, err.Error()))
		hc.lb.SetHealth(backend.Host, false)
		return
	}
	defer resp.Body.Close()

	// fingerbank-collector returns 404 on "/" when healthy
	healthy := resp.StatusCode == hc.config.ExpectedStatusCode

	log.LoggerWContext(ctx).Debug(fmt.Sprintf("Health check result for %s (%s): status=%d, healthy=%v, wasHealthy=%v",
		backend.Host, backend.ManagementIP, resp.StatusCode, healthy, backend.Healthy))

	if healthy && !backend.Healthy {
		log.LoggerWContext(ctx).Info(fmt.Sprintf("Backend %s (%s) is now healthy",
			backend.Host, backend.ManagementIP))
	} else if !healthy && backend.Healthy {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Backend %s (%s) is now unhealthy (status: %d, expected: %d)",
			backend.Host, backend.ManagementIP, resp.StatusCode, hc.config.ExpectedStatusCode))
	}

	hc.lb.SetHealth(backend.Host, healthy)
}

// UpdateConfig updates the health checker configuration.
func (hc *HealthChecker) UpdateConfig(config *ProxyConfig) {
	hc.config = config
	hc.httpClient.Timeout = config.HealthCheckTimeout
}
