package main

import (
	"sync"
	"time"
)

// LoadBalancer implements a failover load balancing strategy for backends.
// Traffic goes to the first healthy backend (primary). Only switches to
// the next backend when the primary becomes unhealthy.
type LoadBalancer struct {
	mu       sync.RWMutex
	backends []*Backend
}

// NewLoadBalancer creates a new load balancer with the given backends.
// Backends are ordered by their position in the slice (first = highest priority).
func NewLoadBalancer(backends []*Backend) *LoadBalancer {
	return &LoadBalancer{
		backends: backends,
	}
}

// GetPrimary returns the first healthy backend (failover mode).
// Returns nil if no healthy backend is available.
func (lb *LoadBalancer) GetPrimary() *Backend {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	for _, backend := range lb.backends {
		if backend.Healthy {
			return backend
		}
	}
	return nil
}

// GetAllBackends returns a copy of all backends for health checking.
func (lb *LoadBalancer) GetAllBackends() []*Backend {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	backends := make([]*Backend, len(lb.backends))
	copy(backends, lb.backends)
	return backends
}

// SetHealth updates the health status of a backend.
func (lb *LoadBalancer) SetHealth(host string, healthy bool) {
	lb.mu.Lock()
	defer lb.mu.Unlock()

	for _, backend := range lb.backends {
		if backend.Host == host {
			backend.Healthy = healthy
			backend.LastCheck = time.Now()
			return
		}
	}
}

// UpdateBackends updates the list of backends, preserving health status
// for existing backends.
func (lb *LoadBalancer) UpdateBackends(newBackends []*Backend) {
	lb.mu.Lock()
	defer lb.mu.Unlock()

	// Create a map of current backend health status
	healthMap := make(map[string]bool)
	lastCheckMap := make(map[string]time.Time)
	for _, b := range lb.backends {
		healthMap[b.Host] = b.Healthy
		lastCheckMap[b.Host] = b.LastCheck
	}

	// Update new backends with preserved health status
	for _, b := range newBackends {
		if healthy, exists := healthMap[b.Host]; exists {
			b.Healthy = healthy
			b.LastCheck = lastCheckMap[b.Host]
		}
	}

	lb.backends = newBackends
}

// HasHealthyBackend returns true if at least one backend is healthy.
func (lb *LoadBalancer) HasHealthyBackend() bool {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	for _, backend := range lb.backends {
		if backend.Healthy {
			return true
		}
	}
	return false
}
