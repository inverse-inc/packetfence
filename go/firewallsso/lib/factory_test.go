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
	spew.Dump(iboss)
}
