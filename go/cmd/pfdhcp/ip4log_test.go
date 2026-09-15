package main

import (
	"testing"
	"time"

	cache "github.com/fdurand/go-cache"
)

// TestIP4LogRenewalOnly covers the gate that lets MysqlUpdateIP4Log replace the
// full mapping check with a single end_time UPDATE.
func TestIP4LogRenewalOnly(t *testing.T) {
	const (
		mac = "00:11:22:33:44:55"
		ip  = "10.0.0.10"
	)
	now := time.Now()

	// Without the cache (nothing initialized it) every packet takes the full
	// path rather than panicking.
	GlobalIP4LogCache = nil
	if ip4logRenewalOnly(mac, ip, now) {
		t.Fatal("expected the full path when the cache is not initialized")
	}

	GlobalIP4LogCache = cache.New(5*time.Minute, 10*time.Minute)

	// A MAC we have never written a row for.
	if ip4logRenewalOnly(mac, ip, now) {
		t.Fatal("expected the full path for an unknown MAC")
	}

	setIP4LogLastWrite(mac, ip, 5*time.Minute)

	if !ip4logRenewalOnly(mac, ip, now) {
		t.Fatal("expected the fast path for a renewal of the same lease")
	}

	// A different address for the same MAC has to go through the full path so
	// the previous row gets closed.
	if ip4logRenewalOnly(mac, "10.0.0.11", now) {
		t.Fatal("expected the full path when the IP changed")
	}

	// The fast path expires on its own so we periodically resynchronize with
	// any other writer of the table.
	if ip4logRenewalOnly(mac, ip, now.Add(ip4logFullSyncInterval+time.Second)) {
		t.Fatal("expected the full path once the full-sync interval elapsed")
	}

	// A lease that is not renewed drops out of the cache with it.
	setIP4LogLastWrite(mac, ip, 10*time.Millisecond)
	time.Sleep(50 * time.Millisecond)
	if ip4logRenewalOnly(mac, ip, now) {
		t.Fatal("expected the full path once the cached lease expired")
	}
}
