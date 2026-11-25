package main

import (
	"context"
	"database/sql"
	"net"
	"testing"

	dhcp "github.com/inverse-inc/dhcp4"
)

func newSplitTestNetwork(t *testing.T, cidr string, role string) Network {
	t.Helper()
	_, ipnet, err := net.ParseCIDR(cidr)
	if err != nil {
		t.Fatalf("Failed to parse CIDR %s: %v", cidr, err)
	}
	ip := append(net.IP(nil), ipnet.IP.To4()...)
	ip[3]++
	return Network{
		network:     *ipnet,
		splittednet: true,
		dhcpHandler: &DHCPHandler{layer2: true, role: role, ip: ip},
	}
}

// A layer 2 network split per role ("IP per role"): the packet must be
// answered by the subnet of the role of the node.
func TestFindHandlerAndNetworkSplitNetwork(t *testing.T) {
	iface := &Interface{
		Name: "eth1",
		network: []Network{
			newSplitTestNetwork(t, "192.0.2.0/26", "default"),
			newSplitTestNetwork(t, "192.0.2.64/26", "guest"),
			newSplitTestNetwork(t, "192.0.2.128/26", "registration"),
		},
	}

	tests := []struct {
		name    string
		node    NodeInfo
		network string
	}{
		{"registered node in default role", NodeInfo{Status: "reg", Category: "default"}, "192.0.2.0/26"},
		{"registered node in guest role", NodeInfo{Status: "reg", Category: "guest"}, "192.0.2.64/26"},
		{"unregistered node", NodeInfo{Status: "unreg", Category: "guest"}, "192.0.2.128/26"},
		{"node without role", NodeInfo{Status: "reg", Category: ""}, "192.0.2.128/26"},
	}

	saved := nodeInformation
	defer func() { nodeInformation = saved }()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			nodeInformation = func(context.Context, net.HardwareAddr, *sql.DB) NodeInfo { return tt.node }

			p := dhcp.NewPacket(dhcp.BootRequest)
			p.SetCHAddr(net.HardwareAddr{0x02, 0x00, 0x00, 0x00, 0x00, 0x01})
			p.SetGIAddr(net.IPv4zero)
			p.SetCIAddr(net.IPv4zero)

			handler, netScope, found := iface.findHandlerAndNetwork(p, p.CHAddr(), nil)
			if !found {
				t.Fatalf("Expected a network for a node %s in role %q, got none", tt.node.Status, tt.node.Category)
			}
			if netScope.String() != tt.network {
				t.Errorf("Expected network %s, got %s", tt.network, netScope.String())
			}
			if len(handler.ip) == 0 {
				t.Errorf("Expected the handler of %s, got an empty one", tt.network)
			}
		})
	}
}
