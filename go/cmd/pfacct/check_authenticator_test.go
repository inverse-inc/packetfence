package main

import (
	"testing"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
)

// An Accounting-Request signed with the switch secret, like a Junos switch
// sends it: no NAS-IP-Address (#9208).
func junosAccountingRequest(t *testing.T, secret string) []byte {
	t.Helper()
	p := radius.New(radius.CodeAccountingRequest, []byte(secret))
	rfc2865.UserName_SetString(p, "024a554e4902")
	rfc2865.CallingStationID_SetString(p, "02-4a-55-4e-49-02")
	rfc2865.CalledStationID_SetString(p, "d0-81-c5-2d-fd-00")
	rfc2866.AcctStatusType_Set(p, rfc2866.AcctStatusType_Value_Start)
	rfc2866.AcctSessionID_SetString(p, "8O2.1x8198000400085a8b")
	raw, err := p.Encode()
	if err != nil {
		t.Fatalf("encode: %s", err)
	}
	return raw
}

func TestCheckAuthenticator(t *testing.T) {
	h := &PfAcct{}
	raw := junosAccountingRequest(t, "switch-secret")

	if err := h.checkAuthenticator(raw, &SwitchInfo{Secret: "switch-secret"}, false); err != nil {
		t.Fatalf("the right secret must validate: %s", err)
	}

	// radius.Parse alone accepts any secret for an Accounting-Request: this is
	// what let the 100.64.0.1 entry answer for the Juniper with its own secret.
	if _, err := radius.Parse(raw, []byte("other-secret")); err != nil {
		t.Fatalf("radius.Parse unexpectedly checked the authenticator: %s", err)
	}
	if err := h.checkAuthenticator(raw, &SwitchInfo{Secret: "other-secret"}, false); err != errBadAuthenticator {
		t.Fatalf("a wrong secret must be rejected, got %v", err)
	}

	// Connector traffic is signed with the unified secret, not the switch's
	h.unifiedSecret = "unified"
	viaConnector := junosAccountingRequest(t, "unified")
	if err := h.checkAuthenticator(viaConnector, &SwitchInfo{Secret: "switch-secret"}, true); err != nil {
		t.Fatalf("connector traffic must validate with the unified secret: %s", err)
	}
	if err := h.checkAuthenticator(viaConnector, &SwitchInfo{Secret: "switch-secret"}, false); err != errBadAuthenticator {
		t.Fatalf("connector traffic must not validate with the switch secret, got %v", err)
	}
}

func TestSwitchFromEndpointCache(t *testing.T) {
	h := &PfAcct{EndpointSwitchCache: cache.New(5*time.Minute, 10*time.Minute)}
	raw := junosAccountingRequest(t, "switch-secret")
	attrs, err := radius.ParseAttributes(raw[20:])
	if err != nil {
		t.Fatalf("parse attributes: %s", err)
	}

	if _, ok := h.switchFromEndpointCache(attrs, raw, false); ok {
		t.Fatal("an empty cache must not identify a switch")
	}

	// Keyed by the normalized Calling-Station-Id
	endpoint := "02:4a:55:4e:49:02"
	h.EndpointSwitchCache.Set(endpoint, &SwitchInfo{Secret: "switch-secret", NasIP: "192.0.2.19"}, cache.DefaultExpiration)
	info, ok := h.switchFromEndpointCache(attrs, raw, false)
	if !ok || info.NasIP != "192.0.2.19" {
		t.Fatalf("the cached switch must be returned while the packet validates with its secret, got %v, %v", info, ok)
	}

	// The endpoint moved to a switch with another secret: forget the entry
	h.EndpointSwitchCache.Set(endpoint, &SwitchInfo{Secret: "other-secret", NasIP: "192.0.2.19"}, cache.DefaultExpiration)
	if _, ok := h.switchFromEndpointCache(attrs, raw, false); ok {
		t.Fatal("a cached switch whose secret does not validate must not be returned")
	}
	if _, found := h.EndpointSwitchCache.Get(endpoint); found {
		t.Fatal("a cached switch whose secret does not validate must be evicted")
	}
}
