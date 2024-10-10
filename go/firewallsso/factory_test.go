package firewallsso

import (
	"testing"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/util"
)

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

func TestFirewallSSOFetchDecodeSocket(t *testing.T) {

	firewall := FirewallSSO{}
	firewall.PfconfigHashNS = "testfw"
	pfconfigdriver.FetchDecodeSocket(ctx, &firewall)

	iboss := Iboss{}
	iboss.PfconfigHashNS = "testfw"
	pfconfigdriver.FetchDecodeSocket(ctx, &iboss)

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
