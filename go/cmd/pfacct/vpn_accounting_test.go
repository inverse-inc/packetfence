package main

import (
	"context"
	"net"
	"testing"

	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2869"
)

// The accounting of a VPN session has no MAC address in its Calling-Station-Id
// (#8671): it is recognized by its user name and its Connect-Info or NAS-Port-Type.
func TestIsVpnAccounting(t *testing.T) {
	type packetDef struct {
		name        string
		userName    string
		connectInfo string
		nasPortType rfc2865.NASPortType
		framedIp    string
		expected    bool
	}

	for _, d := range []packetDef{
		{name: "FortiGate SSL-VPN", userName: "testuser", connectInfo: "vpn-ssl", framedIp: "10.212.134.200", expected: true},
		{name: "FortiGate IPsec", userName: "testuser", connectInfo: "VPN-IPsec", framedIp: "10.212.134.200", expected: true},
		{name: "Virtual NAS-Port-Type", userName: "testuser", nasPortType: rfc2865.NASPortType_Value_Virtual, framedIp: "10.212.134.200", expected: true},
		{name: "no user name", connectInfo: "vpn-ssl", framedIp: "10.212.134.200", expected: false},
		{name: "wired session", userName: "testuser", nasPortType: rfc2865.NASPortType_Value_Ethernet, framedIp: "10.212.134.200", expected: false},
		{name: "admin login", userName: "testuser", connectInfo: "admin-login", framedIp: "10.212.134.200", expected: false},
		// exec / command accounting of a vty login on a switch: Virtual, no tunnel address
		{name: "switch management accounting", userName: "admin", nasPortType: rfc2865.NASPortType_Value_Virtual, expected: false},
		{name: "VPN without tunnel address", userName: "testuser", connectInfo: "vpn-ssl", framedIp: "0.0.0.0", expected: false},
	} {
		p := radius.New(radius.CodeAccountingRequest, []byte("secret"))
		rfc2865.CallingStationID_SetString(p, "203.0.113.10")
		if d.userName != "" {
			rfc2865.UserName_SetString(p, d.userName)
		}
		if d.connectInfo != "" {
			rfc2869.ConnectInfo_SetString(p, d.connectInfo)
		}
		if d.nasPortType != 0 {
			rfc2865.NASPortType_Set(p, d.nasPortType)
		}
		if d.framedIp != "" {
			rfc2865.FramedIPAddress_Set(p, net.ParseIP(d.framedIp))
		}

		if got := isVpnAccounting(p); got != d.expected {
			t.Errorf("%s: isVpnAccounting() = %v, expected %v", d.name, got, d.expected)
		}
	}
}

// Without NAS-IP-Address, the NAS is the switch entry identified for the secret
// (the role was cached under its address at authorization), not the source of
// the packet, which is the bridge gateway behind the docker proxy
func TestVpnAccountingNasIp(t *testing.T) {
	remote := &net.UDPAddr{IP: net.ParseIP("100.64.0.1"), Port: 1813}

	ctx := context.WithValue(context.Background(), switchInfoKey, &SwitchInfo{Nasname: "192.0.2.1"})
	if got := vpnAccountingNasIp(ctx, remote); got != "192.0.2.1" {
		t.Errorf("switch entry with an address: got %s, expected 192.0.2.1", got)
	}

	ctx = context.WithValue(context.Background(), switchInfoKey, &SwitchInfo{Nasname: "192.0.2.0/24"})
	if got := vpnAccountingNasIp(ctx, remote); got != "100.64.0.1" {
		t.Errorf("switch entry with a range: got %s, expected the packet source", got)
	}

	if got := vpnAccountingNasIp(context.Background(), remote); got != "100.64.0.1" {
		t.Errorf("no switch entry: got %s, expected the packet source", got)
	}
}
