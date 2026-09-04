package main

import (
	"bytes"
	"context"
	"database/sql"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	cache "github.com/fdurand/go-cache"
	dhcp "github.com/inverse-inc/dhcp4"
	"github.com/inverse-inc/packetfence/go/dhcp/pool"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// connectorTestScope wires the package globals the way main() does and
// registers a synthetic connector interface with one memory-backed scope
// built from a connector VLAN interface, exactly as buildConnectorInterface
// does but without pfconfig.
func connectorTestScope(t *testing.T) (pfconfigdriver.ConnectorInterface, net.IP) {
	t.Helper()
	ctx = context.Background()
	initializeCaches()
	VIP = map[string]bool{ConnectorInterfaceName: true}
	VIPIp = map[string]net.IP{}
	intNametoInterface = map[string]*Interface{}

	ci := pfconfigdriver.ConnectorInterface{
		Parent: "eth0", Vlan: 100, CIDR: "10.10.100.1/24", Dhcp: "enabled",
		DhcpStart: "10.10.100.10", DhcpEnd: "10.10.100.20",
		DhcpDefaultLeaseTime: "300", DhcpMaxLeaseTime: "600",
		Dns: "8.8.8.8", Gateway: "10.10.100.254", DomainName: "site.example",
	}
	ConfNet, key, scopeIP, err := connectorScopeConf(ci)
	if err != nil {
		t.Fatal(err)
	}
	if key != "10.10.100.0" || ConfNet.Netmask != "255.255.255.0" || !scopeIP.Equal(net.IPv4(10, 10, 100, 1)) {
		t.Fatalf("connectorScopeConf: key=%s mask=%s ip=%s", key, ConfNet.Netmask, scopeIP)
	}

	// Scope built by hand (buildPlainScope needs a DB for initiaLease).
	_, ipnet, _ := net.ParseCIDR("10.10.100.0/24")
	available, err := pool.Create(ctx, "memory", uint64(dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))), key, 1, nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	handler := &DHCPHandler{
		ip:            scopeIP,
		start:         net.ParseIP(ConfNet.DhcpStart),
		leaseRange:    dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd)),
		leaseDuration: 300 * time.Second,
		hwcache:       cache.New(300*time.Second, 2*time.Second),
		xid:           cache.New(4*time.Second, 2*time.Second),
		available:     available,
		layer2:        false,
		role:          "none",
		ipAssigned:    map[string]uint32{},
		dstIp:         ConfNet.DhcpReplyIp,
		options: dhcp.Options{
			dhcp.OptionSubnetMask:       net.ParseIP(ConfNet.Netmask).To4(),
			dhcp.OptionRouter:           net.ParseIP(ConfNet.Gateway).To4(),
			dhcp.OptionDomainNameServer: net.ParseIP(ConfNet.Dns).To4(),
			dhcp.OptionDomainName:       []byte(ConfNet.DomainName),
		},
	}
	intNametoInterface[ConnectorInterfaceName] = &Interface{
		Name:          ConnectorInterfaceName,
		InterfaceType: ConnectorInterfaceType,
		Ipv4:          scopeIP,
		network:       []Network{{network: *ipnet, dhcpHandler: handler}},
	}
	return ci, scopeIP
}

// unreachableDB is a *sql.DB whose every query fails fast: the request path
// tolerates DB errors (option overrides, ip4log) but not a nil handle.
func unreachableDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("mysql", "pf:pf@tcp(127.0.0.1:1)/pf?timeout=200ms")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func postMessage(t *testing.T, body []byte) *httptest.ResponseRecorder {
	t.Helper()
	api := &API{Ctx: context.Background(), DB: unreachableDB(t)}
	req := httptest.NewRequest(http.MethodPost, "/api/v1/dhcp/message", bytes.NewReader(body))
	req.Header.Set("Content-Type", dhcpMessageContentType)
	rec := httptest.NewRecorder()
	api.handleMessage(rec, req)
	return rec
}

func TestHandleMessageDiscoverOffer(t *testing.T) {
	_, vlanIP := connectorTestScope(t)
	mac := net.HardwareAddr{0x00, 0x11, 0x22, 0x33, 0x44, 0x55}

	discover := dhcp.RequestPacket(dhcp.Discover, mac, nil, []byte{1, 2, 3, 4}, false, nil)
	discover.SetGIAddr(vlanIP.To4())
	discover.SetHops(1)

	rec := postMessage(t, discover)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); ct != dhcpMessageContentType {
		t.Errorf("content type %q", ct)
	}
	reply := dhcp.Packet(rec.Body.Bytes())
	if reply.OpCode() != dhcp.BootReply || !bytes.Equal(reply.XId(), discover.XId()) {
		t.Fatalf("not a BOOTREPLY for our xid")
	}
	opts := reply.ParseOptions()
	if dhcp.MessageType(opts[dhcp.OptionDHCPMessageType][0]) != dhcp.Offer {
		t.Fatalf("expected OFFER, got %v", opts[dhcp.OptionDHCPMessageType])
	}
	_, ipnet, _ := net.ParseCIDR("10.10.100.0/24")
	if !ipnet.Contains(reply.YIAddr()) || reply.YIAddr().Equal(vlanIP) {
		t.Errorf("offered %s outside the scope or the interface address", reply.YIAddr())
	}
	// The server identifier is the connector's VLAN address (giaddr), so the
	// client renews against the relay. (pfdhcp never fills siaddr.)
	if !net.IP(opts[dhcp.OptionServerIdentifier]).Equal(vlanIP) {
		t.Errorf("server identifier %s, want %s", net.IP(opts[dhcp.OptionServerIdentifier]), vlanIP)
	}
	if !reply.GIAddr().Equal(vlanIP) {
		t.Errorf("giaddr not echoed: %s", reply.GIAddr())
	}
	if !net.IP(opts[dhcp.OptionRouter]).Equal(net.IPv4(10, 10, 100, 254)) {
		t.Errorf("router option %s", net.IP(opts[dhcp.OptionRouter]))
	}
	if string(opts[dhcp.OptionDomainName]) != "site.example" {
		t.Errorf("domain option %q", opts[dhcp.OptionDomainName])
	}
}

func TestHandleMessageRejectsBadInput(t *testing.T) {
	_, vlanIP := connectorTestScope(t)
	mac := net.HardwareAddr{0x00, 0x11, 0x22, 0x33, 0x44, 0x66}

	// Too short
	if rec := postMessage(t, make([]byte, 100)); rec.Code != http.StatusBadRequest {
		t.Errorf("short body: %d", rec.Code)
	}
	// Not relayed (no giaddr): the connector path requires it
	p := dhcp.RequestPacket(dhcp.Discover, mac, nil, []byte{5, 6, 7, 8}, false, nil)
	if rec := postMessage(t, p); rec.Code != http.StatusBadRequest {
		t.Errorf("no giaddr: %d", rec.Code)
	}
	// A BOOTREPLY is refused
	reply := dhcp.ReplyPacket(p, dhcp.Offer, vlanIP, net.IPv4(10, 10, 100, 11), time.Hour, nil)
	if rec := postMessage(t, reply); rec.Code != http.StatusBadRequest {
		t.Errorf("bootreply: %d", rec.Code)
	}
	// Unknown scope (giaddr in another network): pfdhcp has nothing to say
	p.SetGIAddr(net.IPv4(192, 168, 1, 1).To4())
	if rec := postMessage(t, p); rec.Code != http.StatusNoContent {
		t.Errorf("unknown scope: %d %s", rec.Code, rec.Body.String())
	}
}

func TestConnectorScopeConfDefaultsAndErrors(t *testing.T) {
	ci := pfconfigdriver.ConnectorInterface{Parent: "eth0", Vlan: 5, CIDR: "10.0.5.1/24", Dhcp: "enabled", DhcpStart: "10.0.5.10", DhcpEnd: "10.0.5.20"}
	conf, key, ip, err := connectorScopeConf(ci)
	if err != nil {
		t.Fatal(err)
	}
	if key != "10.0.5.0" || conf.Gateway != "10.0.5.1" || conf.DhcpDefaultLeaseTime != "300" || conf.DhcpMaxLeaseTime != "600" || conf.IpReserved != "" || !ip.Equal(net.IPv4(10, 0, 5, 1)) {
		t.Errorf("defaults: %+v key=%s ip=%s", conf, key, ip)
	}
	// Captive DNS enabled and no DNS given: clients get the interface address
	ci.DnsServer = "enabled"
	conf, _, _, _ = connectorScopeConf(ci)
	if conf.Dns != "10.0.5.1" {
		t.Errorf("dns default with dns_server enabled: %q", conf.Dns)
	}
	ci.Dns = "1.1.1.1"
	conf, _, _, _ = connectorScopeConf(ci)
	if conf.Dns != "1.1.1.1" {
		t.Errorf("explicit dns overridden: %q", conf.Dns)
	}
	ci.Dns, ci.DnsServer = "", ""
	// Interface address inside the range is kept out of the pool
	ci.DhcpStart = "10.0.5.1"
	conf, _, _, _ = connectorScopeConf(ci)
	if conf.IpReserved != "10.0.5.1" {
		t.Errorf("interface address not reserved: %q", conf.IpReserved)
	}
	// Range outside the network
	ci.DhcpStart, ci.DhcpEnd = "10.0.6.10", "10.0.6.20"
	if _, _, _, err := connectorScopeConf(ci); err == nil {
		t.Errorf("range outside the network accepted")
	}
	ci.CIDR = "not-an-address"
	if _, _, _, err := connectorScopeConf(ci); err == nil {
		t.Errorf("invalid cidr accepted")
	}
}
