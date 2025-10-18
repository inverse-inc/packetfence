package main

import (
	"context"
	"net"
	"testing"

	dhcp "github.com/inverse-inc/dhcp4"
)

func TestJob(t *testing.T) {
	job := job{
		DHCPpacket: dhcp.NewPacket(dhcp.BootRequest),
		msgType:    dhcp.Discover,
		Int:        &Interface{Name: "eth0"},
		clientAddr: &net.UDPAddr{IP: net.IPv4(192, 168, 1, 100), Port: 68},
		srvAddr:    net.IPv4(192, 168, 1, 1),
		localCtx:   context.Background(),
	}

	if job.msgType != dhcp.Discover {
		t.Errorf("job.msgType = %v, want %v", job.msgType, dhcp.Discover)
	}
	if job.Int.Name != "eth0" {
		t.Errorf("job.Int.Name = %v, want eth0", job.Int.Name)
	}
	if job.srvAddr.String() != "192.168.1.1" {
		t.Errorf("job.srvAddr = %v, want 192.168.1.1", job.srvAddr.String())
	}
}

func TestJobStruct(t *testing.T) {
	packet := dhcp.NewPacket(dhcp.BootRequest)
	packet.SetCHAddr([]byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff})
	packet.SetXId([]byte{0x12, 0x34, 0x56, 0x78})

	iface := &Interface{
		Name:       "eth0",
		Ipv4:       net.IPv4(192, 168, 1, 1),
		listenPort: 67,
	}

	clientAddr := &net.UDPAddr{
		IP:   net.IPv4(192, 168, 1, 100),
		Port: 68,
	}

	job := job{
		DHCPpacket: packet,
		msgType:    dhcp.Request,
		Int:        iface,
		clientAddr: clientAddr,
		srvAddr:    net.IPv4(192, 168, 1, 1),
		localCtx:   context.Background(),
	}

	// Test that job fields are properly set
	if job.DHCPpacket == nil {
		t.Error("job.DHCPpacket is nil")
	}
	if job.msgType != dhcp.Request {
		t.Errorf("job.msgType = %v, want %v", job.msgType, dhcp.Request)
	}
	if job.Int == nil {
		t.Error("job.Int is nil")
	}
	if job.clientAddr == nil {
		t.Error("job.clientAddr is nil")
	}
	if job.srvAddr == nil {
		t.Error("job.srvAddr is nil")
	}
	if job.localCtx == nil {
		t.Error("job.localCtx is nil")
	}

	// Verify client address
	udpAddr, ok := job.clientAddr.(*net.UDPAddr)
	if !ok {
		t.Error("job.clientAddr is not a *net.UDPAddr")
	} else {
		if udpAddr.IP.String() != "192.168.1.100" {
			t.Errorf("job.clientAddr.IP = %v, want 192.168.1.100", udpAddr.IP)
		}
		if udpAddr.Port != 68 {
			t.Errorf("job.clientAddr.Port = %v, want 68", udpAddr.Port)
		}
	}

	// Verify interface
	if job.Int.Name != "eth0" {
		t.Errorf("job.Int.Name = %v, want eth0", job.Int.Name)
	}
}

func TestJobCreationWithContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	job := job{
		DHCPpacket: dhcp.NewPacket(dhcp.BootRequest),
		msgType:    dhcp.Discover,
		localCtx:   ctx,
	}

	if job.localCtx == nil {
		t.Error("job.localCtx should not be nil")
	}

	// Test context cancellation
	cancel()
	select {
	case <-job.localCtx.Done():
		// Context was properly cancelled
	default:
		t.Error("Context should be cancelled")
	}
}

func TestJobWithDHCPPacket(t *testing.T) {
	packet := dhcp.NewPacket(dhcp.BootRequest)
	packet.SetCHAddr([]byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff})
	packet.SetGIAddr(net.IPv4(192, 168, 1, 254))

	job := job{
		DHCPpacket: packet,
		msgType:    dhcp.Offer,
	}

	if job.DHCPpacket.GIAddr().String() != "192.168.1.254" {
		t.Errorf("job.DHCPpacket.GIAddr() = %v, want 192.168.1.254", job.DHCPpacket.GIAddr())
	}
}
