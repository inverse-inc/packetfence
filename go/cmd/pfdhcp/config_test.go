package main

import (
	"net"
	"testing"
	"time"

	cache "github.com/fdurand/go-cache"
	dhcp "github.com/inverse-inc/dhcp4"
)

func TestNewDHCPConfig(t *testing.T) {
	p := newDHCPConfig()
	if p == nil {
		t.Error("newDHCPConfig() returned nil")
	}
	if p.intsNet != nil {
		t.Error("newDHCPConfig() intsNet should be nil initially")
	}
}

func TestDHCPHandlerCreation(t *testing.T) {
	handler := &DHCPHandler{
		ip:            net.IPv4(192, 168, 1, 1),
		vip:           net.IPv4(192, 168, 1, 2),
		options:       dhcp.Options{},
		start:         net.IPv4(192, 168, 1, 100),
		leaseRange:    100,
		leaseDuration: 24 * time.Hour,
		hwcache:       cache.New(5*time.Minute, 10*time.Minute),
		xid:           cache.New(5*time.Minute, 10*time.Minute),
		layer2:        true,
		role:          "default",
		ipReserved:    "",
		ipAssigned:    make(map[string]uint32),
		dstIp:         "client",
	}

	if handler.ip.String() != "192.168.1.1" {
		t.Errorf("Expected IP 192.168.1.1, got %s", handler.ip.String())
	}
	if handler.leaseRange != 100 {
		t.Errorf("Expected lease range 100, got %d", handler.leaseRange)
	}
	if handler.leaseDuration != 24*time.Hour {
		t.Errorf("Expected lease duration 24h, got %v", handler.leaseDuration)
	}
	if !handler.layer2 {
		t.Error("Expected layer2 to be true")
	}
}

func TestInterfaceCreation(t *testing.T) {
	iface := Interface{
		Name:          "eth0",
		Ipv4:          net.IPv4(192, 168, 1, 1),
		Ipv6:          net.IPv6zero,
		InterfaceType: "management",
		listenPort:    67,
	}

	if iface.Name != "eth0" {
		t.Errorf("Expected name eth0, got %s", iface.Name)
	}
	if iface.Ipv4.String() != "192.168.1.1" {
		t.Errorf("Expected IPv4 192.168.1.1, got %s", iface.Ipv4.String())
	}
	if iface.listenPort != 67 {
		t.Errorf("Expected listen port 67, got %d", iface.listenPort)
	}
}

func TestNetworkCreation(t *testing.T) {
	_, ipnet, err := net.ParseCIDR("192.168.1.0/24")
	if err != nil {
		t.Fatalf("Failed to parse CIDR: %v", err)
	}

	network := Network{
		network: *ipnet,
		dhcpHandler: &DHCPHandler{
			start:      net.IPv4(192, 168, 1, 100),
			leaseRange: 50,
		},
		splittednet: false,
	}

	if network.network.String() != "192.168.1.0/24" {
		t.Errorf("Expected network 192.168.1.0/24, got %s", network.network.String())
	}
	if network.dhcpHandler == nil {
		t.Error("Expected dhcpHandler to be set")
	}
	if network.splittednet {
		t.Error("Expected splittednet to be false")
	}
}

func TestBootpConstants(t *testing.T) {
	if bootpClient != 68 {
		t.Errorf("Expected bootpClient to be 68, got %d", bootpClient)
	}
	if bootpServer != 67 {
		t.Errorf("Expected bootpServer to be 67, got %d", bootpServer)
	}
}
