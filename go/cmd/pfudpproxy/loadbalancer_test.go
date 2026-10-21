package main

import (
	"sync"
	"testing"
	"time"
)

// newTestBackends creates a slice of backends for use in tests.
func newTestBackends() []*Backend {
	return []*Backend{
		{Host: "node1", ManagementIP: "10.0.0.1"},
		{Host: "node2", ManagementIP: "10.0.0.2"},
		{Host: "node3", ManagementIP: "10.0.0.3"},
	}
}

func TestGetPrimary_ReturnsFirstHealthy(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = true
	backends[1].Healthy = true
	lb := NewLoadBalancer(backends)

	primary := lb.GetPrimary()
	if primary == nil {
		t.Fatal("expected a primary backend, got nil")
	}
	if primary.Host != "node1" {
		t.Errorf("expected primary to be node1, got %s", primary.Host)
	}
}

func TestGetPrimary_SkipsUnhealthy(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = false
	backends[1].Healthy = true
	lb := NewLoadBalancer(backends)

	primary := lb.GetPrimary()
	if primary == nil {
		t.Fatal("expected a primary backend, got nil")
	}
	if primary.Host != "node2" {
		t.Errorf("expected primary to be node2, got %s", primary.Host)
	}
}

func TestGetPrimary_NoneHealthy(t *testing.T) {
	lb := NewLoadBalancer(newTestBackends())

	if primary := lb.GetPrimary(); primary != nil {
		t.Errorf("expected nil when no backend is healthy, got %s", primary.Host)
	}
}

func TestGetPrimary_ReturnsSnapshot(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = true
	lb := NewLoadBalancer(backends)

	snapshot := lb.GetPrimary()
	snapshot.Host = "mutated"

	// The internal backend must be unaffected.
	primary := lb.GetPrimary()
	if primary.Host != "node1" {
		t.Errorf("mutating snapshot affected internal state: got %s", primary.Host)
	}
}

func TestGetAllBackends_ReturnsAllBackends(t *testing.T) {
	backends := newTestBackends()
	lb := NewLoadBalancer(backends)

	all := lb.GetAllBackends()
	if len(all) != 3 {
		t.Fatalf("expected 3 backends, got %d", len(all))
	}
	for i, b := range all {
		if b.Host != backends[i].Host {
			t.Errorf("backend[%d]: expected host %s, got %s", i, backends[i].Host, b.Host)
		}
	}
}

func TestGetAllBackends_ReturnsValueCopies(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = true
	lb := NewLoadBalancer(backends)

	all := lb.GetAllBackends()
	all[0].Healthy = false
	all[0].Host = "mutated"

	// The internal backend must be unaffected.
	primary := lb.GetPrimary()
	if primary == nil {
		t.Fatal("mutating snapshot affected internal healthy state")
	}
	if primary.Host != "node1" {
		t.Errorf("mutating snapshot affected internal host: got %s", primary.Host)
	}
}

func TestSetHealth_UpdatesBackend(t *testing.T) {
	lb := NewLoadBalancer(newTestBackends())

	before := time.Now()
	lb.SetHealth("node2", true)

	all := lb.GetAllBackends()
	for _, b := range all {
		if b.Host == "node2" {
			if !b.Healthy {
				t.Error("expected node2 to be healthy after SetHealth(true)")
			}
			if b.LastCheck.Before(before) {
				t.Error("expected LastCheck to be updated")
			}
			return
		}
	}
	t.Error("node2 not found in backends")
}

func TestSetHealth_UnknownHostIsNoop(t *testing.T) {
	lb := NewLoadBalancer(newTestBackends())

	// Should not panic or change anything.
	lb.SetHealth("nonexistent", true)

	if lb.HasHealthyBackend() {
		t.Error("expected no healthy backends after setting unknown host")
	}
}

func TestSetHealth_TransitionHealthyToUnhealthy(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = true
	lb := NewLoadBalancer(backends)

	lb.SetHealth("node1", false)

	if lb.HasHealthyBackend() {
		t.Error("expected no healthy backends after marking node1 unhealthy")
	}
}

func TestSetHealth_FailoverOnPrimaryDown(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = true
	backends[1].Healthy = true
	lb := NewLoadBalancer(backends)

	// Primary is node1. Mark it unhealthy — node2 should take over.
	lb.SetHealth("node1", false)

	primary := lb.GetPrimary()
	if primary == nil {
		t.Fatal("expected a primary backend after failover")
	}
	if primary.Host != "node2" {
		t.Errorf("expected failover to node2, got %s", primary.Host)
	}
}

func TestUpdateBackends_PreservesHealthStatus(t *testing.T) {
	backends := newTestBackends()
	lb := NewLoadBalancer(backends)

	lb.SetHealth("node1", true)
	lb.SetHealth("node3", true)

	// Simulate a config reload with the same hosts but fresh Backend structs.
	updated := []*Backend{
		{Host: "node1", ManagementIP: "10.0.0.1"},
		{Host: "node2", ManagementIP: "10.0.0.2"},
		{Host: "node3", ManagementIP: "10.0.0.3"},
	}
	lb.UpdateBackends(updated)

	all := lb.GetAllBackends()
	expect := map[string]bool{"node1": true, "node2": false, "node3": true}
	for _, b := range all {
		if b.Healthy != expect[b.Host] {
			t.Errorf("backend %s: expected healthy=%v, got %v", b.Host, expect[b.Host], b.Healthy)
		}
	}
}

func TestUpdateBackends_PreservesLastCheck(t *testing.T) {
	backends := newTestBackends()
	lb := NewLoadBalancer(backends)

	lb.SetHealth("node1", true)

	// Capture the LastCheck that SetHealth wrote.
	before := lb.GetAllBackends()
	var savedCheck time.Time
	for _, b := range before {
		if b.Host == "node1" {
			savedCheck = b.LastCheck
		}
	}

	updated := []*Backend{
		{Host: "node1", ManagementIP: "10.0.0.1"},
	}
	lb.UpdateBackends(updated)

	after := lb.GetAllBackends()
	if after[0].LastCheck != savedCheck {
		t.Errorf("expected LastCheck to be preserved across UpdateBackends")
	}
}

func TestUpdateBackends_NewBackendStartsUnhealthy(t *testing.T) {
	backends := newTestBackends()
	lb := NewLoadBalancer(backends)
	lb.SetHealth("node1", true)

	// Replace with a completely new host.
	updated := []*Backend{
		{Host: "node4", ManagementIP: "10.0.0.4"},
	}
	lb.UpdateBackends(updated)

	if lb.HasHealthyBackend() {
		t.Error("new backend should start unhealthy")
	}
}

func TestUpdateBackends_RemovesOldBackends(t *testing.T) {
	backends := newTestBackends()
	lb := NewLoadBalancer(backends)

	updated := []*Backend{
		{Host: "node2", ManagementIP: "10.0.0.2"},
	}
	lb.UpdateBackends(updated)

	all := lb.GetAllBackends()
	if len(all) != 1 {
		t.Fatalf("expected 1 backend after update, got %d", len(all))
	}
	if all[0].Host != "node2" {
		t.Errorf("expected remaining backend to be node2, got %s", all[0].Host)
	}
}

func TestHasHealthyBackend(t *testing.T) {
	lb := NewLoadBalancer(newTestBackends())

	if lb.HasHealthyBackend() {
		t.Error("expected false when all backends are unhealthy")
	}

	lb.SetHealth("node3", true)

	if !lb.HasHealthyBackend() {
		t.Error("expected true after marking node3 healthy")
	}
}

func TestGetPrimary_EmptyBackends(t *testing.T) {
	lb := NewLoadBalancer(nil)
	if primary := lb.GetPrimary(); primary != nil {
		t.Errorf("expected nil for empty backend list, got %s", primary.Host)
	}

	lb2 := NewLoadBalancer([]*Backend{})
	if primary := lb2.GetPrimary(); primary != nil {
		t.Errorf("expected nil for zero-length backend list, got %s", primary.Host)
	}
}

func TestGetPrimary_SingleBackend(t *testing.T) {
	lb := NewLoadBalancer([]*Backend{
		{Host: "only", ManagementIP: "10.0.0.1", Healthy: true},
	})

	primary := lb.GetPrimary()
	if primary == nil || primary.Host != "only" {
		t.Fatalf("expected single healthy backend, got %v", primary)
	}
}

func TestGetPrimary_OrderDeterminesPriority(t *testing.T) {
	backends := []*Backend{
		{Host: "low-priority", ManagementIP: "10.0.0.3", Healthy: true},
		{Host: "mid-priority", ManagementIP: "10.0.0.2", Healthy: true},
		{Host: "high-priority", ManagementIP: "10.0.0.1", Healthy: true},
	}
	lb := NewLoadBalancer(backends)

	// First element in slice is always the primary, regardless of naming.
	primary := lb.GetPrimary()
	if primary == nil || primary.Host != "low-priority" {
		t.Errorf("expected first backend in slice to be primary, got %v", primary)
	}
}

func TestUpdateBackends_EmptySliceRemovesAll(t *testing.T) {
	lb := NewLoadBalancer(newTestBackends())
	lb.SetHealth("node1", true)

	lb.UpdateBackends([]*Backend{})

	all := lb.GetAllBackends()
	if len(all) != 0 {
		t.Errorf("expected 0 backends after empty update, got %d", len(all))
	}
	if lb.HasHealthyBackend() {
		t.Error("expected no healthy backends after clearing list")
	}
}

func TestUpdateBackends_ReorderChangesPriority(t *testing.T) {
	backends := newTestBackends()
	lb := NewLoadBalancer(backends)
	lb.SetHealth("node1", true)
	lb.SetHealth("node2", true)

	// Primary is node1 (index 0).
	primary := lb.GetPrimary()
	if primary == nil || primary.Host != "node1" {
		t.Fatalf("expected node1 as initial primary, got %v", primary)
	}

	// Reorder: put node2 first. Health should be preserved.
	reordered := []*Backend{
		{Host: "node2", ManagementIP: "10.0.0.2"},
		{Host: "node1", ManagementIP: "10.0.0.1"},
	}
	lb.UpdateBackends(reordered)

	// Now node2 is first and healthy, so it becomes primary.
	primary = lb.GetPrimary()
	if primary == nil || primary.Host != "node2" {
		t.Errorf("expected node2 as primary after reorder, got %v", primary)
	}
}

func TestSetHealth_RecoveryAfterAllDown(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = true
	backends[1].Healthy = true
	lb := NewLoadBalancer(backends)

	// Take all backends down.
	lb.SetHealth("node1", false)
	lb.SetHealth("node2", false)
	lb.SetHealth("node3", false)

	if lb.HasHealthyBackend() {
		t.Fatal("expected no healthy backends")
	}

	// Recover node3 (the last one). It should become primary.
	lb.SetHealth("node3", true)
	primary := lb.GetPrimary()
	if primary == nil || primary.Host != "node3" {
		t.Errorf("expected node3 as primary after recovery, got %v", primary)
	}
}

func TestConcurrent_SetHealthAndGetPrimary(t *testing.T) {
	backends := newTestBackends()
	backends[0].Healthy = true
	lb := NewLoadBalancer(backends)

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 200

	// Half the goroutines toggle health, the other half read primary.
	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		if i%2 == 0 {
			go func(id int) {
				defer wg.Done()
				host := backends[id%len(backends)].Host
				for j := 0; j < iterations; j++ {
					lb.SetHealth(host, j%2 == 0)
				}
			}(i)
		} else {
			go func() {
				defer wg.Done()
				for j := 0; j < iterations; j++ {
					_ = lb.GetPrimary()
				}
			}()
		}
	}

	wg.Wait()
	// No panic or race detector failure is the assertion.
}

func TestConcurrent_UpdateBackendsAndGetPrimary(t *testing.T) {
	lb := NewLoadBalancer(newTestBackends())
	lb.SetHealth("node1", true)

	var wg sync.WaitGroup
	const iterations = 200

	wg.Add(3)

	// Writer: repeatedly replace the backend list.
	go func() {
		defer wg.Done()
		for i := 0; i < iterations; i++ {
			fresh := []*Backend{
				{Host: "node1", ManagementIP: "10.0.0.1"},
				{Host: "node2", ManagementIP: "10.0.0.2"},
			}
			lb.UpdateBackends(fresh)
		}
	}()

	// Reader 1: GetPrimary.
	go func() {
		defer wg.Done()
		for i := 0; i < iterations; i++ {
			_ = lb.GetPrimary()
		}
	}()

	// Reader 2: GetAllBackends.
	go func() {
		defer wg.Done()
		for i := 0; i < iterations; i++ {
			_ = lb.GetAllBackends()
		}
	}()

	wg.Wait()
}
