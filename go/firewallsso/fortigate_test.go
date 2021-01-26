package firewallsso

import (
	"testing"

	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
	//"github.com/davecgh/go-spew/spew"
)

func TestFortiGateStartRadiusPacket(t *testing.T) {
	f := FortiGate{Password: "secret"}

	p := f.startRadiusPacket(ctx, sampleInfo, 86400)

	if rfc2866.AcctStatusType_Get(p) != 1 {
		t.Errorf("Incorrect Acct-Status-Type in SSO packet.")
	}

	if rfc2865.FramedIPAddress_Get(p).String() != sampleInfo["ip"] {
		t.Errorf("Incorrect Framed-IP-Address in SSO packet.")
	}

	if string(rfc2865.UserName_Get(p)) != sampleInfo["username"] {
		t.Errorf("Incorrect User-Name in SSO packet.")
	}

	if string(rfc2865.CallingStationID_Get(p)) != sampleInfo["mac"] {
		t.Errorf("Incorrect Calling-Station-Id in SSO packet.")
	}
}

func TestFortiGateStopRadiusPacket(t *testing.T) {
	f := FortiGate{Password: "secret"}

	p := f.stopRadiusPacket(ctx, sampleInfo)

	if rfc2866.AcctStatusType_Get(p) != 2 {
		t.Errorf("Incorrect Acct-Status-Type in SSO packet.")
	}

	if rfc2865.FramedIPAddress_Get(p).String() != sampleInfo["ip"] {
		t.Errorf("Incorrect Framed-IP-Address in SSO packet.")
	}

	if string(rfc2865.UserName_Get(p)) != sampleInfo["username"] {
		t.Errorf("Incorrect User-Name in SSO packet.")
	}

	if string(rfc2865.CallingStationID_Get(p)) != sampleInfo["mac"] {
		t.Errorf("Incorrect Calling-Station-Id in SSO packet.")
	}
}
