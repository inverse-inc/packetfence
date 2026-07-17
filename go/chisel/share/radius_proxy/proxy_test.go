package radius_proxy

import (
	"bytes"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/pfradius"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
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

// addConnectorID stamps the PacketFence-ConnectorID VSA (vendor 29464, attr 40)
// the way the remote FreeRADIUS does on a proxied request, mirroring the
// construction inside ProxyPacket.
func addConnectorID(p *radius.Packet, id string) {
	v, _ := radius.NewString(id)
	vendorAttr := make(radius.Attribute, 2+len(v))
	vendorAttr[0] = pfradius.ConnectorIDAttrType
	vendorAttr[1] = byte(len(vendorAttr))
	copy(vendorAttr[2:], v)
	vsa, _ := radius.NewVendorSpecific(pfradius.VendorID, vendorAttr)
	p.Attributes.Add(26, vsa)
}

// A request the remote FreeRADIUS already proxied arrives tagged with
// Proxy-State + PacketFence-ConnectorID and signed with the unified secret.
// ProxyPacket must forward those exact bytes: re-encoding an Accounting-Request
// would recompute a Request Authenticator that the cloud pfacct then rejects,
// and would inject a bogus Message-Authenticator. It must still route by code.
func TestProxyPacketForwardsPreTaggedVerbatim(t *testing.T) {
	rp := newTestProxy()

	p := radius.New(radius.CodeAccountingRequest, rp.secret)
	rfc2865.ProxyState_SetString(p, "already-proxied")
	addConnectorID(p, "connX")
	payload, err := p.Encode()
	if err != nil {
		t.Fatalf("encode: %v", err)
	}

	out, addr, err := rp.ProxyPacket(payload, "connX")
	if err != nil {
		t.Fatalf("ProxyPacket returned error: %v", err)
	}
	if !bytes.Equal(out, payload) {
		t.Errorf("pre-tagged packet was not forwarded verbatim:\n got %v\nwant %v", out, payload)
	}
	if addr != testAcctAddr {
		t.Errorf("accounting packet routed to %q, want %q", addr, testAcctAddr)
	}
}

// A bare request (e.g. a Status-Server liveness probe) arrives untagged.
// ProxyPacket must add Proxy-State + ConnectorID and re-sign with the unified
// secret, so the output differs from the input, carries the ConnectorID VSA,
// and still parses under the unified secret.
func TestProxyPacketResignsUntaggedPacket(t *testing.T) {
	rp := newTestProxy()

	p := radius.New(radius.CodeAccessRequest, rp.secret)
	payload, err := p.Encode()
	if err != nil {
		t.Fatalf("encode: %v", err)
	}

	out, addr, err := rp.ProxyPacket(payload, "connX")
	if err != nil {
		t.Fatalf("ProxyPacket returned error: %v", err)
	}
	if bytes.Equal(out, payload) {
		t.Error("untagged packet was forwarded verbatim; expected it to be re-signed")
	}
	if addr != testAuthAddr {
		t.Errorf("access packet routed to %q, want %q", addr, testAuthAddr)
	}

	reparsed, err := radius.Parse(out, rp.secret)
	if err != nil {
		t.Fatalf("re-signed packet does not parse under the unified secret: %v", err)
	}
	if !hasPacketFenceConnectorID(reparsed) {
		t.Error("re-signed packet is missing the PacketFence-ConnectorID VSA")
	}
}
