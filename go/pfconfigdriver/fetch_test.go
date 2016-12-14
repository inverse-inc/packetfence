package pfconfigdriver

import (
	"context"
	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/firewallsso/lib"
	"testing"
)

var ctx = context.Background()

func TestFetchSocket(t *testing.T) {
	result := FetchSocket(ctx, `{"method":"element", "key":"resource::fqdn","encoding":"json"}`+"\n")
	expected := `{"element":"pf-julien.inverse.ca"}`
	if string(result) != expected {
		t.Errorf("Response payload isn't correct '%s' instead of '%s'", result, expected)
	}
}

func TestFetchDecodeSocket(t *testing.T) {
	general := PfConfGeneral{}
	FetchDecodeSocketStruct(ctx, &general)

	if general.Domain != "inverse.ca" {
		t.Error("PfConfGeneral wasn't fetched and parsed correctly")
		spew.Dump(general)
	}

	firewall := libfirewallsso.FirewallSSO{}
	firewall.PfconfigHashNS = "test"
	FetchDecodeSocketStruct(ctx, &firewall)
	spew.Dump(firewall)

	iboss := libfirewallsso.Iboss{}
	iboss.PfconfigHashNS = "test"
	FetchDecodeSocketStruct(ctx, &iboss)

	if iboss.Port != "8015" || iboss.Type != "Iboss" {
		t.Error("IBoss wasn't fetched and parsed correctly")
		spew.Dump(iboss)
	}

	var sections ConfigSections
	sections.PfconfigNS = "config::Pf"
	FetchDecodeSocketStruct(ctx, &sections)

	generalFound := false
	for i := range sections.Keys {
		if sections.Keys[i] == "general" {
			generalFound = true
		}
	}

	if !generalFound {
		t.Error("pf.conf sections couldn't be fetched correctly")
		spew.Dump(sections)
	}

}
