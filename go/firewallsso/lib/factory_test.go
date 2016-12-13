package libfirewallsso

import (
	"github.com/davecgh/go-spew/spew"
	"testing"
)

func TestInstantiate(t *testing.T) {
	factory := NewFactory()
	firewall := factory.Instantiate("test")

	iboss := firewall.(*Iboss)

	if iboss.Password != "XS832CF2A" {
		t.Error("Password of FirewallSSO doesn't have the right value")
		spew.Dump(iboss)
	}
	if iboss.Type != "Iboss" {
		t.Error("Type of FirewallSSO doesn't have the right value")
		spew.Dump(iboss)
	}
}

func TestStart(t *testing.T) {
	factory := NewFactory()
	iboss := factory.Instantiate("test").(*Iboss)

	result := iboss.Start(map[string]string{"ip": "1.2.3.4", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
	if !result {
		t.Error("Iboss SSO didn't succeed with valid parameters")
	}

	result = iboss.Start(map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
	if result {
		t.Error("Iboss SSO succeeded with invalid parameters")
	}

	paloalto := factory.Instantiate("paloalto.com")

	result = paloalto.Start(map[string]string{"ip": "1.2.3.4", "role": "gaming", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

	if !result {
		t.Error("PaloAlto SSO failed with valid parameters")
	}

	result = paloalto.Start(map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

	if result {
		t.Error("PaloAlto SSO succeeded with invalid parameters")
	}
}
