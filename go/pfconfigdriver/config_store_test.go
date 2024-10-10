package pfconfigdriver

import (
	"context"
	"testing"
)

func TestRefresh(t *testing.T) {
	cs := NewConfigStore()
	updater := cs.updater()
	updater.AddStruct(context.Background(), "PfConfGeneral", &PfConfGeneral{})
	data := cs.GetStruct("PfConfGeneral")
	if data == nil {
		t.Fatalf("Could not get PfConfGeneral")
	}

	updater.Refresh(context.Background())
	item2 := cs.GetStruct("PfConfGeneral").(*PfConfGeneral)
	if item2.Domain != "pfdemo.org" {
		t.Fatalf("Domain is not set expected: %s got :%s", "pfdemo.org", item2.Domain)
	}

	clone := cs.Clone()
	item2 = clone.GetStruct("PfConfGeneral").(*PfConfGeneral)
	if item2.Domain != "pfdemo.org" {
		t.Fatalf("Cloned Domain is not set expected: %s got :%s", "pfdemo.org", item2.Domain)
	}

}
