package main

import (
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
		expected    bool
	}

	for _, d := range []packetDef{
		{name: "FortiGate SSL-VPN", userName: "jbon", connectInfo: "vpn-ssl", expected: true},
		{name: "FortiGate IPsec", userName: "jbon", connectInfo: "VPN-IPsec", expected: true},
		{name: "Virtual NAS-Port-Type", userName: "jbon", nasPortType: rfc2865.NASPortType_Value_Virtual, expected: true},
		{name: "no user name", connectInfo: "vpn-ssl", expected: false},
		{name: "wired session", userName: "jbon", nasPortType: rfc2865.NASPortType_Value_Ethernet, expected: false},
		{name: "admin login", userName: "jbon", connectInfo: "admin-login", expected: false},
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

		if got := isVpnAccounting(p); got != d.expected {
			t.Errorf("%s: isVpnAccounting() = %v, expected %v", d.name, got, d.expected)
		}
	}
}
