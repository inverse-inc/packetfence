package pfconfigdriver

import (
	"github.com/davecgh/go-spew/spew"
	"os"
	"testing"
	"time"
)

func TestLoadResource(t *testing.T) {
	rp := NewResourcePool(ctx)
	gen := PfConfGeneral{}
	rp.LoadResource(ctx, &gen, false)

	expected := "pfdemo.org"
	if gen.Domain != expected {
		t.Error("Resource domain wasn't loaded correctly through resource pool. Got %s instead of %s", gen.Domain, expected)
	}

	if _, ok := rp.loadedResources["pfconfigdriver.PfConfGeneral"]; !ok {
		t.Error("The loaded resource wasn't stored in the pool")
	}

	spew.Dump(rp)
}

func TestResourceIsValid(t *testing.T) {
	rp := NewResourcePool(ctx)

	gen := PfConfGeneral{}
	rp.LoadResource(ctx, &gen, false)

	res := rp.loadedResources["pfconfigdriver.PfConfGeneral"]
	if !res.IsValid(ctx) {
		t.Error("Resource isn't valid although it was just loaded")
	}

	os.Chtimes(res.controlFile(), time.Now(), time.Now())

	if res.IsValid(ctx) {
		t.Error("Resource is valid although the control file was just touched")
	}
}
