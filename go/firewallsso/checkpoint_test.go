package firewallsso

import (
	"net"
	"testing"
)

func TestCheckpointStartRadiusPacket(t *testing.T) {
	f := Checkpoint{Password: "secret"}

	p := f.startRadiusPacket(ctx, sampleInfo, 86400)

	if p.Value("Acct-Status-Type").(uint32) != 1 {
		t.Errorf("Incorrect Acct-Status-Type in SSO packet.")
	}

	if p.Value("Framed-IP-Address").(net.IP).String() != sampleInfo["ip"] {
		t.Errorf("Incorrect Framed-IP-Address in SSO packet.")
	}

	if p.Value("User-Name").(string) != sampleInfo["username"] {
		t.Errorf("Incorrect User-Name in SSO packet.")
	}

	if p.Value("Calling-Station-Id").(string) != sampleInfo["mac"] {
		t.Errorf("Incorrect Calling-Station-Id in SSO packet.")
	}

	if p.Value("Session-Timeout").(uint32) != 86400 {
		t.Errorf("Incorrect Calling-Station-Id in SSO packet.")
	}
}
