package main

import (
	"net"
	"testing"

	dhcp "github.com/inverse-inc/dhcp4"
)

func newTestNetwork(t *testing.T, cidr string, layer2 bool) Network {
	t.Helper()
	_, ipnet, err := net.ParseCIDR(cidr)
	if err != nil {
		t.Fatalf("Failed to parse CIDR %s: %v", cidr, err)
	}
	return Network{
		network:     *ipnet,
		dhcpHandler: &DHCPHandler{layer2: layer2},
	}
}

func newTestPacket(giaddr, ciaddr net.IP) dhcp.Packet {
	p := dhcp.NewPacket(dhcp.BootRequest)
	p.SetCHAddr(net.HardwareAddr{0x02, 0x00, 0x00, 0x00, 0x00, 0x01})
	p.SetGIAddr(giaddr)
	p.SetCIAddr(ciaddr)
	return p
}

// A layer 2 network (the subnet of the interface) and a routed network whose
// next hop is in that subnet, on the same interface.
func TestFindHandlerAndNetworkLayer2AndRouted(t *testing.T) {
	iface := &Interface{
		Name: "eth1",
		network: []Network{
			newTestNetwork(t, "192.0.2.0/24", true),
			newTestNetwork(t, "198.51.100.0/24", false),
		},
	}

	tests := []struct {
		name    string
		giaddr  net.IP
		ciaddr  net.IP
		network string
	}{
		{"relayed discover", net.IPv4(198, 51, 100, 1), net.IPv4zero, "198.51.100.0/24"},
		{"routed client renewing by unicast", net.IPv4zero, net.IPv4(198, 51, 100, 65), "198.51.100.0/24"},
		{"layer 2 client discover", net.IPv4zero, net.IPv4zero, "192.0.2.0/24"},
		{"layer 2 client renewing", net.IPv4zero, net.IPv4(192, 0, 2, 50), "192.0.2.0/24"},
		{"unknown address without relay", net.IPv4zero, net.IPv4(203, 0, 113, 10), "192.0.2.0/24"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, netScope, found := iface.findHandlerAndNetwork(newTestPacket(tt.giaddr, tt.ciaddr), nil, nil)
			if !found {
				t.Fatalf("Expected a network for giaddr %s ciaddr %s, got none", tt.giaddr, tt.ciaddr)
			}
			if netScope.String() != tt.network {
				t.Errorf("Expected network %s for giaddr %s ciaddr %s, got %s", tt.network, tt.giaddr, tt.ciaddr, netScope.String())
			}
		})
	}
}

func TestRoutedNetworkContains(t *testing.T) {
	iface := &Interface{
		network: []Network{
			newTestNetwork(t, "192.0.2.0/24", true),
			newTestNetwork(t, "198.51.100.0/24", false),
		},
	}

	if !iface.routedNetworkContains(net.IPv4(198, 51, 100, 65)) {
		t.Error("Expected 198.51.100.65 to be in a routed network")
	}
	if iface.routedNetworkContains(net.IPv4(192, 0, 2, 50)) {
		t.Error("Expected 192.0.2.50 not to be in a routed network")
	}
	if iface.routedNetworkContains(net.IPv4zero) {
		t.Error("Expected 0.0.0.0 not to be in a routed network")
	}
	if iface.routedNetworkContains(nil) {
		t.Error("Expected nil not to be in a routed network")
	}
}
