package libfirewallsso

import (
	"context"
	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/logging"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/util"
	"testing"
)

var ctx = logging.NewContext(context.Background())

func TestInstantiate(t *testing.T) {
	factory := NewFactory(ctx)
	firewall, err := factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)

	if err == nil {
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
}

func TestStart(t *testing.T) {
	factory := NewFactory(ctx)
	o, err := factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)
	iboss := o.(*Iboss)

	if err == nil {
		result := ExecuteStart(ctx, iboss, map[string]string{"ip": "1.2.3.4", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
		if !result {
			t.Error("Iboss SSO didn't succeed with valid parameters")
		}

		result = ExecuteStart(ctx, iboss, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
		if result {
			t.Error("Iboss SSO succeeded with invalid parameters")
		}
	}

	paloalto, err := factory.Instantiate(ctx, "paloalto.com")
	util.CheckTestError(t, err)

	if err == nil {
		result := ExecuteStart(ctx, paloalto, map[string]string{"ip": "1.2.3.4", "role": "gaming", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

		if !result {
			t.Error("PaloAlto SSO failed with valid parameters")
		}

		result = ExecuteStart(ctx, paloalto, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

		if result {
			t.Error("PaloAlto SSO succeeded with invalid parameters")
		}
	}
}

func TestFirewallSSOFetchDecodeSocket(t *testing.T) {

	firewall := FirewallSSO{}
	firewall.PfconfigHashNS = "testfw"
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &firewall)

	iboss := Iboss{}
	iboss.PfconfigHashNS = "testfw"
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &iboss)

	if iboss.Port != "8015" || iboss.Type != "Iboss" {
		t.Error("IBoss wasn't fetched and parsed correctly")
		spew.Dump(iboss)
	}

}

func TestBadData(t *testing.T) {
	factory := NewFactory(ctx)
	_, err := factory.Instantiate(ctx, "invalid_type")
	if err == nil {
		t.Error("Didn't get an error while instantiating a firewall with an invalid type")
	}

	_, err = factory.Instantiate(ctx, "invalid_id")

	if err == nil {
		t.Error("Didn't get an error while instantiating a firewall that doesn't exist")
	}
}
