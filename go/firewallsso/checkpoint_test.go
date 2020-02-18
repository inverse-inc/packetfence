package firewallsso

import (
	"testing"

	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
)

func TestCheckpointStartRadiusPacket(t *testing.T) {
	f := Checkpoint{Password: "secret"}

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

	if rfc2865.SessionTimeout_Get(p) != 86400 {
		t.Errorf("Incorrect Calling-Station-Id in SSO packet.")
	}
}
