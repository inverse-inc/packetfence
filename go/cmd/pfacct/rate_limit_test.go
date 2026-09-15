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
	return rateLimitTestAttrOn("aa:bb:cc:dd:ee:ff", framedIP)
}

func rateLimitTestAttrOn(calledStation, framedIP string) map[string]interface{} {
	return map[string]interface{}{
		"Calling-Station-Id": "00:11:22:33:44:55",
		"Called-Station-Id":  calledStation,
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

func TestRateLimitReRegistersExpiredSession(t *testing.T) {
	h := rateLimitTestAcct()
	attr := rateLimitTestAttr("192.0.2.10")

	if !h.rateLimit(attr, rfc2866.AcctStatusType_Value_Start) {
		t.Fatal("first Start should be forwarded")
	}
	// Sessions routinely outlive pfacct_rate_limit_cache_ttl; only an IP
	// change refreshes the key, so it eventually ages out under a live
	// session.
	h.RateLimitCache.Flush()

	if !h.rateLimit(attr, rfc2866.AcctStatusType_Value_InterimUpdate) {
		t.Error("Interim-Update for a session with no cached Start should be forwarded")
	}
	if h.rateLimit(attr, rfc2866.AcctStatusType_Value_InterimUpdate) {
		t.Error("the re-registered session should suppress the next unchanged Interim-Update")
	}
	// Re-registering must also re-arm the IP change detection.
	if !h.rateLimit(rateLimitTestAttr("192.0.2.11"), rfc2866.AcctStatusType_Value_InterimUpdate) {
		t.Error("Interim-Update with a new IP should be forwarded after re-registration")
	}
}

func TestRateLimitForwardsRoamBack(t *testing.T) {
	h := rateLimitTestAcct()
	nasA := rateLimitTestAttrOn("aa:bb:cc:dd:ee:ff", "192.0.2.10")
	nasB := rateLimitTestAttrOn("99:99:99:99:99:99", "192.0.2.10")

	if !h.rateLimit(nasA, rfc2866.AcctStatusType_Value_Start) {
		t.Fatal("first Start on the first NAS should be forwarded")
	}
	if _, found := h.MacNasCache.Get("00:11:22:33:44:55"); !found {
		t.Fatal("a device's first Start must record its location, or the roaming purge can never fire")
	}
	if !h.rateLimit(nasB, rfc2866.AcctStatusType_Value_Start) {
		t.Fatal("Start on a second NAS should be forwarded")
	}
	// Roaming back within the TTL must not look like a suppressible repeat:
	// the AAA layer needs it to update the locationlog.
	if !h.rateLimit(nasA, rfc2866.AcctStatusType_Value_Start) {
		t.Error("Start after roaming back to the first NAS should be forwarded")
	}
}

func TestRateLimitTtlFloor(t *testing.T) {
	// go-cache reads a non-positive duration as "never expires", which would
	// pin every session for the lifetime of the process.
	for _, ttl := range []int{0, -1} {
		h := &PfAcct{PfacctRateLimitCacheTtl: ttl}
		if got := h.rateLimitTtl(); got != DefaultRateLimitCacheTtl*time.Minute {
			t.Errorf("rateLimitTtl with a configured ttl of %d: got %s", ttl, got)
		}
	}

	h := &PfAcct{PfacctRateLimitCacheTtl: 7}
	if got := h.rateLimitTtl(); got != 7*time.Minute {
		t.Errorf("rateLimitTtl with a configured ttl of 7: got %s", got)
	}
}
