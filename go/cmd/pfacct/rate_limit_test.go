package main

import (
	"testing"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/go-radius/rfc2866"
)

func rateLimitTestAcct() *PfAcct {
	return &PfAcct{
		RateLimitCache:          cache.New(5*time.Minute, 10*time.Minute),
		MacNasCache:             cache.New(5*time.Minute, 10*time.Minute),
		PfacctRateLimitCacheTtl: 5,
	}
}

func rateLimitTestAttr(framedIP string) map[string]interface{} {
	return map[string]interface{}{
		"Calling-Station-Id": "00:11:22:33:44:55",
		"Called-Station-Id":  "aa:bb:cc:dd:ee:ff",
		"Framed-IP-Address":  framedIP,
	}
}

func TestRateLimitSuppressesRepeats(t *testing.T) {
	h := rateLimitTestAcct()
	attr := rateLimitTestAttr("192.0.2.10")

	if !h.rateLimit(attr, rfc2866.AcctStatusType_Value_Start) {
		t.Error("first Start should be forwarded")
	}
	if h.rateLimit(attr, rfc2866.AcctStatusType_Value_Start) {
		t.Error("duplicate Start with the same IP should be suppressed")
	}
	if h.rateLimit(attr, rfc2866.AcctStatusType_Value_InterimUpdate) {
		t.Error("Interim-Update with an unchanged IP should be suppressed")
	}
	if !h.rateLimit(rateLimitTestAttr("192.0.2.11"), rfc2866.AcctStatusType_Value_InterimUpdate) {
		t.Error("Interim-Update with a new IP should be forwarded")
	}
}

func TestRateLimitAlwaysForwardsStop(t *testing.T) {
	h := rateLimitTestAcct()
	attr := rateLimitTestAttr("192.0.2.10")

	// Stop must pass even for a session whose Start was never cached
	// (e.g. sessions established before pfacct started).
	if !h.rateLimit(attr, rfc2866.AcctStatusType_Value_Stop) {
		t.Error("Stop without a cached Start must be forwarded")
	}

	if !h.rateLimit(attr, rfc2866.AcctStatusType_Value_Start) {
		t.Error("first Start should be forwarded")
	}
	if !h.rateLimit(attr, rfc2866.AcctStatusType_Value_Stop) {
		t.Error("Stop with an unchanged IP must still be forwarded")
	}
	// Stop cleared the session key, so a new session's Start passes again.
	if !h.rateLimit(attr, rfc2866.AcctStatusType_Value_Start) {
		t.Error("Start after Stop should be forwarded")
	}
}
