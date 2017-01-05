package libfirewallsso

import (
	"context"
	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/logging"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"testing"
)

var ctx = logging.NewContext(context.Background())

func TestInstantiate(t *testing.T) {
	factory := NewFactory(ctx)
	firewall := factory.Instantiate(ctx, "test")

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
	factory := NewFactory(ctx)
	iboss := factory.Instantiate(ctx, "test").(*Iboss)

	result := ExecuteStart(ctx, iboss, map[string]string{"ip": "1.2.3.4", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
	if !result {
		t.Error("Iboss SSO didn't succeed with valid parameters")
	}

	result = ExecuteStart(ctx, iboss, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
	if result {
		t.Error("Iboss SSO succeeded with invalid parameters")
	}

	paloalto := factory.Instantiate(ctx, "paloalto.com")

	result = ExecuteStart(ctx, paloalto, map[string]string{"ip": "1.2.3.4", "role": "gaming", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

	if !result {
		t.Error("PaloAlto SSO failed with valid parameters")
	}

	result = ExecuteStart(ctx, paloalto, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

	if result {
		t.Error("PaloAlto SSO succeeded with invalid parameters")
	}
}

func TestFirewallSSOFetchDecodeSocket(t *testing.T) {

	firewall := FirewallSSO{}
	firewall.PfconfigHashNS = "test"
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &firewall)

	iboss := Iboss{}
	iboss.PfconfigHashNS = "test"
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &iboss)

	if iboss.Port != "8015" || iboss.Type != "Iboss" {
		t.Error("IBoss wasn't fetched and parsed correctly")
		spew.Dump(iboss)
	}

}
