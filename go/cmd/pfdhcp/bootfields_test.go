package main

import (
	"net"
	"testing"
	"time"

	dhcp "github.com/inverse-inc/dhcp4"
)

func TestSetBootFields(t *testing.T) {
	req := dhcp.RequestPacket(dhcp.Discover, net.HardwareAddr{0, 0x1b, 0x21, 0x49, 0x73, 1}, nil, []byte{1, 2, 3, 4}, false, nil)

	reply := dhcp.ReplyPacket(req, dhcp.Offer, net.IPv4(192, 168, 43, 1), net.IPv4(192, 168, 43, 10), time.Minute, nil)
	setBootFields(reply, dhcp.Options{
		dhcp.OptionTFTPServerName: []byte("192.168.43.5"),
		dhcp.OptionBootFileName:   []byte("undionly.kpxe"),
	})
	if got := reply.SIAddr().String(); got != "192.168.43.5" {
		t.Errorf("siaddr = %s, want 192.168.43.5", got)
	}
	if got := string(reply.SName()); got != "192.168.43.5" {
		t.Errorf("sname = %q, want 192.168.43.5", got)
	}
	if got := string(reply.File()); got != "undionly.kpxe" {
		t.Errorf("file = %q, want undionly.kpxe", got)
	}

	// A TFTP server name that isn't an IP only goes in sname
	reply = dhcp.ReplyPacket(req, dhcp.Offer, net.IPv4(192, 168, 43, 1), net.IPv4(192, 168, 43, 10), time.Minute, nil)
	setBootFields(reply, dhcp.Options{dhcp.OptionTFTPServerName: []byte("tftp.example.com")})
	if got := reply.SIAddr().String(); got != "0.0.0.0" {
		t.Errorf("siaddr = %s, want 0.0.0.0 for a hostname", got)
	}
	if got := string(reply.SName()); got != "tftp.example.com" {
		t.Errorf("sname = %q, want tftp.example.com", got)
	}

	// Without options 66/67 the BOOTP fields stay empty
	reply = dhcp.ReplyPacket(req, dhcp.Offer, net.IPv4(192, 168, 43, 1), net.IPv4(192, 168, 43, 10), time.Minute, nil)
	setBootFields(reply, dhcp.Options{})
	if reply.SIAddr().String() != "0.0.0.0" || len(reply.SName()) != 0 || len(reply.File()) != 0 {
		t.Errorf("BOOTP fields set without options: siaddr=%s sname=%q file=%q", reply.SIAddr(), reply.SName(), reply.File())
	}
}
