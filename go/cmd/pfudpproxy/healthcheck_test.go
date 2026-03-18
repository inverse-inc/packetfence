package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"sync/atomic"
	"testing"
	"time"
)

// parseServerURL extracts the hostname and port from an httptest server URL.
func parseServerURL(t *testing.T, serverURL string) (host string, port int) {
	t.Helper()
	u, err := url.Parse(serverURL)
	if err != nil {
		t.Fatalf("failed to parse server URL %q: %v", serverURL, err)
	}
	host = u.Hostname()
	port, err = strconv.Atoi(u.Port())
	if err != nil {
		t.Fatalf("failed to parse port from server URL %q: %v", serverURL, err)
	}
	return host, port
}

// setupSingleBackend creates a HealthChecker backed by one backend whose
// ManagementIP and health-check port match the given httptest TLS server.
// The returned HealthChecker uses the server's TLS client so that the
// self-signed certificate is trusted.
func setupSingleBackend(t *testing.T, server *httptest.Server, expectedStatus int) (*HealthChecker, *LoadBalancer) {
	t.Helper()

	host, port := parseServerURL(t, server.URL)

	lb := NewLoadBalancer([]*Backend{
		{Host: "test-backend", ManagementIP: host},
	})

	config := &ProxyConfig{
		HealthCheckPort:     port,
		HealthCheckPath:     "/",
		HealthCheckInterval: 1 * time.Second,
		HealthCheckTimeout:  2 * time.Second,
		ExpectedStatusCode:  expectedStatus,
	}

	hc := NewHealthChecker(config, lb)
	hc.httpClient = server.Client()
	hc.httpClient.Timeout = 2 * time.Second
	return hc, lb
}

func TestCheckBackend_HealthyWhenExpectedStatus(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	hc, lb := setupSingleBackend(t, server, http.StatusNotFound)

	backends := lb.GetAllBackends()
	hc.checkBackend(context.Background(), backends[0])

	primary := lb.GetPrimary()
	if primary == nil {
		t.Fatal("expected backend to be healthy, but GetPrimary returned nil")
	}
	if primary.Host != "test-backend" {
		t.Errorf("expected primary host to be test-backend, got %s", primary.Host)
	}
}

func TestCheckBackend_UnhealthyWhenUnexpectedStatus(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	// Expected 404 but server returns 200 → unhealthy.
	hc, lb := setupSingleBackend(t, server, http.StatusNotFound)

	backends := lb.GetAllBackends()
	hc.checkBackend(context.Background(), backends[0])

	if primary := lb.GetPrimary(); primary != nil {
		t.Errorf("expected no healthy backend, but got %s", primary.Host)
	}
}

func TestCheckBackend_UnhealthyOnConnectionError(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))

	// Grab the URL before closing so we can parse host:port.
	host, port := parseServerURL(t, server.URL)
	server.Close()

	lb := NewLoadBalancer([]*Backend{
		{Host: "test-backend", ManagementIP: host},
	})
	config := &ProxyConfig{
		HealthCheckPort:     port,
		HealthCheckPath:     "/",
		HealthCheckInterval: 1 * time.Second,
		HealthCheckTimeout:  2 * time.Second,
		ExpectedStatusCode:  http.StatusNotFound,
	}
	hc := NewHealthChecker(config, lb)

	backends := lb.GetAllBackends()
	hc.checkBackend(context.Background(), backends[0])

	if primary := lb.GetPrimary(); primary != nil {
		t.Errorf("expected no healthy backend after connection error, but got %s", primary.Host)
	}
}

func TestCheckBackend_TransitionHealthyToUnhealthy(t *testing.T) {
	var statusCode atomic.Int32
	statusCode.Store(http.StatusNotFound)

	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(int(statusCode.Load()))
	}))
	defer server.Close()

	hc, lb := setupSingleBackend(t, server, http.StatusNotFound)

	// First check: server returns 404 (expected) → healthy.
	backends := lb.GetAllBackends()
	hc.checkBackend(context.Background(), backends[0])

	if primary := lb.GetPrimary(); primary == nil {
		t.Fatal("expected backend to be healthy after first check")
	}

	// Change server response to 500 → unhealthy.
	statusCode.Store(http.StatusInternalServerError)

	backends = lb.GetAllBackends()
	hc.checkBackend(context.Background(), backends[0])

	if primary := lb.GetPrimary(); primary != nil {
		t.Errorf("expected backend to be unhealthy after status change, but got %s", primary.Host)
	}
}

func TestCheckBackend_TransitionUnhealthyToHealthy(t *testing.T) {
	var statusCode atomic.Int32
	statusCode.Store(http.StatusInternalServerError)

	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(int(statusCode.Load()))
	}))
	defer server.Close()

	hc, lb := setupSingleBackend(t, server, http.StatusNotFound)

	// First check: server returns 500 → unhealthy.
	backends := lb.GetAllBackends()
	hc.checkBackend(context.Background(), backends[0])

	if primary := lb.GetPrimary(); primary != nil {
		t.Errorf("expected backend to be unhealthy, but got %s", primary.Host)
	}

	// Change server response to 404 (expected) → healthy.
	statusCode.Store(http.StatusNotFound)

	backends = lb.GetAllBackends()
	hc.checkBackend(context.Background(), backends[0])

	if primary := lb.GetPrimary(); primary == nil {
		t.Fatal("expected backend to become healthy after status change")
	}
}

func TestCheckAllBackends_MultipleBackends(t *testing.T) {
	// All backends share the same HealthCheckPort, so both will hit the
	// same httptest server (both ManagementIPs resolve to 127.0.0.1).
	// We verify that checkAllBackends processes every backend in
	// parallel and applies the health result to each.

	var statusCode atomic.Int32
	statusCode.Store(http.StatusNotFound)

	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(int(statusCode.Load()))
	}))
	defer server.Close()

	host, port := parseServerURL(t, server.URL)

	lb := NewLoadBalancer([]*Backend{
		{Host: "backend1", ManagementIP: host},
		{Host: "backend2", ManagementIP: host},
	})
	config := &ProxyConfig{
		HealthCheckPort:     port,
		HealthCheckPath:     "/",
		HealthCheckInterval: 1 * time.Second,
		HealthCheckTimeout:  2 * time.Second,
		ExpectedStatusCode:  http.StatusNotFound,
	}
	hc := NewHealthChecker(config, lb)
	hc.httpClient = server.Client()
	hc.httpClient.Timeout = 2 * time.Second

	// Server returns 404 → both backends should become healthy.
	hc.checkAllBackends(context.Background())

	all := lb.GetAllBackends()
	for _, b := range all {
		if !b.Healthy {
			t.Errorf("expected %s to be healthy after checkAllBackends", b.Host)
		}
	}

	// Change server to return 500 → both should become unhealthy.
	statusCode.Store(http.StatusInternalServerError)

	hc.checkAllBackends(context.Background())

	all = lb.GetAllBackends()
	for _, b := range all {
		if b.Healthy {
			t.Errorf("expected %s to be unhealthy after status change", b.Host)
		}
	}
}

func TestCheckAllBackends_EmptyBackends(t *testing.T) {
	lb := NewLoadBalancer(nil)

	config := &ProxyConfig{
		HealthCheckPort:     4723,
		HealthCheckPath:     "/",
		HealthCheckInterval: 1 * time.Second,
		HealthCheckTimeout:  2 * time.Second,
		ExpectedStatusCode:  http.StatusNotFound,
	}
	hc := NewHealthChecker(config, lb)

	// Should not panic with zero backends.
	hc.checkAllBackends(context.Background())

	if primary := lb.GetPrimary(); primary != nil {
		t.Errorf("expected nil primary with no backends, got %v", primary)
	}
}

func TestHealthCheckerUpdateConfig(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	hc, _ := setupSingleBackend(t, server, http.StatusNotFound)

	newConfig := &ProxyConfig{
		HealthCheckPort:     4723,
		HealthCheckPath:     "/",
		HealthCheckInterval: 10 * time.Second,
		HealthCheckTimeout:  30 * time.Second,
		ExpectedStatusCode:  http.StatusNotFound,
	}
	hc.UpdateConfig(newConfig)

	if hc.config.HealthCheckInterval != 10*time.Second {
		t.Errorf("expected interval 10s, got %v", hc.config.HealthCheckInterval)
	}
	if hc.httpClient.Timeout != 30*time.Second {
		t.Errorf("expected timeout 30s, got %v", hc.httpClient.Timeout)
	}
}
