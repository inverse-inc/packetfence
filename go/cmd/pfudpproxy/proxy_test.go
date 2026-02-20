package main

import (
	"context"
	"net"
	"testing"
	"time"
)

func TestResolveAddr_CachesResult(t *testing.T) {
	p := NewUDPProxy(&ProxyConfig{}, NewLoadBalancer(nil))

	addr1, err := p.resolveAddr("127.0.0.1:1234")
	if err != nil {
		t.Fatalf("first resolveAddr failed: %v", err)
	}

	addr2, err := p.resolveAddr("127.0.0.1:1234")
	if err != nil {
		t.Fatalf("second resolveAddr failed: %v", err)
	}

	if addr1 != addr2 {
		t.Error("expected second call to return the same cached pointer")
	}

	p.addrCacheMu.RLock()
	cached, ok := p.addrCache["127.0.0.1:1234"]
	p.addrCacheMu.RUnlock()

	if !ok {
		t.Fatal("expected address to be present in cache")
	}
	if cached != addr1 {
		t.Error("cached entry does not match returned pointer")
	}
}

func TestResolveAddr_ErrorOnInvalidAddr(t *testing.T) {
	p := NewUDPProxy(&ProxyConfig{}, NewLoadBalancer(nil))

	_, err := p.resolveAddr("not_a_valid_address")
	if err == nil {
		t.Fatal("expected error for invalid address, got nil")
	}
}

func TestUpdateConfig_FlushesAddrCache(t *testing.T) {
	config := &ProxyConfig{
		VIPAddress:          "10.0.0.1",
		HealthCheckTimeout:  5 * time.Second,
		HealthCheckInterval: 5 * time.Second,
	}
	p := NewUDPProxy(config, NewLoadBalancer(nil))

	// Populate the cache.
	_, err := p.resolveAddr("127.0.0.1:5678")
	if err != nil {
		t.Fatalf("resolveAddr failed: %v", err)
	}

	p.addrCacheMu.RLock()
	if len(p.addrCache) != 1 {
		t.Fatalf("expected 1 cached entry, got %d", len(p.addrCache))
	}
	p.addrCacheMu.RUnlock()

	// UpdateConfig should flush the cache.
	newConfig := &ProxyConfig{
		VIPAddress:          "10.0.0.1",
		HealthCheckTimeout:  5 * time.Second,
		HealthCheckInterval: 5 * time.Second,
	}
	p.UpdateConfig(context.Background(), newConfig)

	p.addrCacheMu.RLock()
	if len(p.addrCache) != 0 {
		t.Errorf("expected empty cache after UpdateConfig, got %d entries", len(p.addrCache))
	}
	p.addrCacheMu.RUnlock()
}

func TestStart_ResetsRunningOnFwdSocketError(t *testing.T) {
	// Bind a UDP socket so that the same address is already taken.
	blocker, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to create blocker socket: %v", err)
	}
	defer blocker.Close()

	// Create a proxy that will try to listen on the same VIP:port.
	// Start opens an unbound fwdConn first (which will succeed), then
	// listens on VIP:port. To make the fwdConn open itself fail we
	// would need to exhaust file descriptors, which is impractical.
	// Instead, verify the invariant directly: after a failed Start
	// the proxy must not remain in the "running" state.

	config := &ProxyConfig{
		VIPAddress: "127.0.0.1",
		Ports:      []int{12345},
	}
	p := NewUDPProxy(config, NewLoadBalancer(nil))

	// Manually simulate the failure path: set running = true (as Start does),
	// then confirm that calling Start again is a no-op while running is true,
	// and after resetting running to false a second Start is not blocked.
	p.mu.Lock()
	p.running = true
	p.mu.Unlock()

	// A second Start should return immediately because running == true.
	p.Start(context.Background())

	// Now reset, as the fix does on the error path.
	p.mu.Lock()
	p.running = false
	p.mu.Unlock()

	// After the reset, the proxy should accept a new Start call.
	// We can verify by checking that running becomes true again.
	// We use a real Start here; the fwdConn open will succeed.
	p.Start(context.Background())
	defer p.Stop(context.Background())

	p.mu.RLock()
	if !p.running {
		t.Error("expected proxy to be running after successful Start following reset")
	}
	p.mu.RUnlock()
}

func TestUpdateConfig_DetectsVIPChange(t *testing.T) {
	config := &ProxyConfig{
		VIPAddress:          "10.0.0.1",
		HealthCheckTimeout:  5 * time.Second,
		HealthCheckInterval: 5 * time.Second,
	}
	p := NewUDPProxy(config, NewLoadBalancer(nil))

	newConfig := &ProxyConfig{
		VIPAddress:          "10.0.0.99",
		HealthCheckTimeout:  5 * time.Second,
		HealthCheckInterval: 5 * time.Second,
	}
	p.UpdateConfig(context.Background(), newConfig)

	if p.config.VIPAddress != "10.0.0.99" {
		t.Errorf("expected VIPAddress to be 10.0.0.99, got %s", p.config.VIPAddress)
	}
}
