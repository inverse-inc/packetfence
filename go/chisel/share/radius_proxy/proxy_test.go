package radius_proxy

import (
	"testing"
	"time"

	"layeh.com/radius"
)

const (
	testAuthAddr = "10.0.0.1:1812"
	testAcctAddr = "10.0.0.2:1813"
)

func newTestProxy() *Proxy {
	return NewProxy(&ProxyConfig{
		AuthAddrs:      []string{testAuthAddr},
		AcctAddrs:      []string{testAcctAddr},
		Secret:         []byte("testing123"),
		SessionTimeout: time.Second,
	})
}

// Accounting-Request must land on the accounting pool (pfacct) and everything
// else on the authentication pool (radiusd-auth). Collapsing the two pools, or
// routing accounting through the auth pool, sends Accounting-Request to the
// auth port where it is silently discarded.
func TestBackendsForPacketRoutesByCode(t *testing.T) {
	rp := newTestProxy()

	tests := []struct {
		name string
		code radius.Code
		want *Backends
	}{
		{"accounting -> acct pool", radius.CodeAccountingRequest, rp.acctBackends},
		{"access -> auth pool", radius.CodeAccessRequest, rp.authBackends},
		{"status-server -> auth pool", radius.CodeStatusServer, rp.authBackends},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			p := radius.New(tc.code, []byte("testing123"))
			if got := rp.backendsForPacket(p); got != tc.want {
				t.Fatalf("backendsForPacket(%s) routed to the wrong pool", tc.code)
			}
		})
	}
}

// The backend actually selected for a packet must come from the pool that
// matches its code.
func TestProxyPicksBackendFromCorrectPool(t *testing.T) {
	rp := newTestProxy()

	acct := radius.New(radius.CodeAccountingRequest, []byte("testing123"))
	if be := rp.backendsForPacket(acct).pickBackend(acct); be == nil || be.addr != testAcctAddr {
		t.Fatalf("accounting packet picked %v, want %s", be, testAcctAddr)
	}

	access := radius.New(radius.CodeAccessRequest, []byte("testing123"))
	if be := rp.backendsForPacket(access).pickBackend(access); be == nil || be.addr != testAuthAddr {
		t.Fatalf("access packet picked %v, want %s", be, testAuthAddr)
	}
}
