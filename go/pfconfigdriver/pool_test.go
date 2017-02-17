package pfconfigdriver

import (
	"github.com/fingerbank/processor/sharedutils"
	"os"
	"os/exec"
	"testing"
	"time"
)

func TestLoadResource(t *testing.T) {
	rp := NewResourcePool(ctx)
	gen := PfConfGeneral{}

	// Test loading a resource and validating the result
	loaded, err := rp.LoadResource(ctx, &gen, true)
	sharedutils.CheckTestError(t, err)

	if !loaded {
		t.Error("Resource wasn't loaded when calling a first time load")
	}

	expected := "pfdemo.org"
	if gen.Domain != expected {
		t.Errorf("Resource domain wasn't loaded correctly through resource pool. Got %s instead of %s", gen.Domain, expected)
	}

	query := createQuery(ctx, &gen)
	_, ok := rp.loadedResources[query.GetPayload()]
	if !ok {
		t.Error("The loaded resource wasn't stored in the pool")
		return
	}

	// Test loading a resource with the firstLoad flag which should reload from pfconfig even though there is another resource that uses the same struct
	gen = PfConfGeneral{}
	loaded, err = rp.LoadResource(ctx, &gen, true)
	sharedutils.CheckTestError(t, err)

	if !loaded {
		t.Error("Resource wasn't loaded when calling a first time load")
	}

	// Test loading a resource without the firstLoad flag which shouldn't read from pfconfig
	gen = PfConfGeneral{}
	loaded, err = rp.LoadResource(ctx, &gen, true)
	sharedutils.CheckTestError(t, err)

	if !loaded {
		t.Error("Resource wasn't loaded when calling a first time load")
	}

	expected = "pfdemo.org"
	if gen.Domain != expected {
		t.Errorf("Resource domain wasn't loaded correctly through resource pool. Got %s instead of %s", gen.Domain, expected)
	}

	// Test changing data in pfconfig and reloading the resource
	cmd := exec.Command("sed", "-i.bak", "s/domain=pfdemo.org/domain=zammitcorp.com/g", "/usr/local/pf/t/data/pf.conf")
	err = cmd.Run()
	sharedutils.CheckError(err)

	// Expire data in pfconfig
	FetchSocket(ctx, `{"method":"expire", "encoding":"json", "namespace":"config::Pf"}`+"\n")

	// Load the resource while accepting the reusal of the data already populated in the resource
	loaded, err = rp.LoadResource(ctx, &gen, false)
	sharedutils.CheckTestError(t, err)

	if !loaded {
		t.Error("Resource wasn't loaded when control file expired")
	}

	expected = "zammitcorp.com"
	if gen.Domain != expected {
		t.Errorf("Resource domain wasn't loaded correctly through resource pool. Got %s instead of %s", gen.Domain, expected)
	}
	// Restore the prestine version of pf.conf
	err = os.Rename("/usr/local/pf/t/data/pf.conf.bak", "/usr/local/pf/t/data/pf.conf")
	sharedutils.CheckError(err)

	// Reset the pfconfig namespace after putting back the old data
	FetchSocket(ctx, `{"method":"expire", "encoding":"json", "namespace":"config::Pf"}`+"\n")

}

func TestResourceIsValid(t *testing.T) {
	rp := NewResourcePool(ctx)

	gen := PfConfGeneral{}
	rp.LoadResource(ctx, &gen, false)

	query := createQuery(ctx, &gen)
	res := rp.loadedResources[query.GetPayload()]
	if !res.IsValid(ctx) {
		t.Error("Resource isn't valid although it was just loaded")
	}

	os.Chtimes(res.controlFile(), time.Now(), time.Now())

	if res.IsValid(ctx) {
		t.Error("Resource is valid although the control file was just touched")
	}
}

func TestResourcePoolResourceIsValid(t *testing.T) {
	rp := NewResourcePool(ctx)

	gen := PfConfGeneral{}

	if rp.ResourceIsValid(ctx, &gen) {
		t.Error("Resource is valid although it was never loaded")
	}

	rp.LoadResource(ctx, &gen, true)

	if !rp.ResourceIsValid(ctx, &gen) {
		t.Error("Resource is invalid but should be valid")
	}
}

func TestResourcePoolFindResource(t *testing.T) {
	rp := NewResourcePool(ctx)

	gen := PfConfGeneral{}

	if _, ok := rp.FindResource(ctx, &gen); ok {
		t.Error("Resource was found in the pool although it was never loaded")
	}

	rp.LoadResource(ctx, &gen, true)

	if _, ok := rp.FindResource(ctx, &gen); !ok {
		t.Error("Resource wasn't found in the pool although it was loaded")
	}
}
