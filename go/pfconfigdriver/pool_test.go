package pfconfigdriver

import (
	"github.com/davecgh/go-spew/spew"
	"github.com/fingerbank/processor/sharedutils"
	"os"
	"os/exec"
	"testing"
	"time"
)

func TestLoadResource(t *testing.T) {
	rp := NewResourcePool(ctx)
	gen := PfConfGeneral{}
	rp.LoadResource(ctx, &gen, true)

	expected := "pfdemo.org"
	if gen.Domain != expected {
		t.Error("Resource domain wasn't loaded correctly through resource pool. Got %s instead of %s", gen.Domain, expected)
	}

	res, ok := rp.loadedResources["pfconfigdriver.PfConfGeneral"]
	if !ok {
		t.Error("The loaded resource wasn't stored in the pool")
		return
	}

	cmd := exec.Command("sed", "-i.bak", "s/domain=pfdemo.org/domain=zammitcorp.com/g", "/usr/local/pf/t/data/pf.conf")
	err := cmd.Run()
	sharedutils.CheckError(err)

	// Expire data in pfconfig
	FetchSocket(ctx, `{"method":"expire", "encoding":"json", "namespace":"config::Pf"}`+"\n")

	os.Chtimes(res.controlFile(), time.Now(), time.Now())

	rp.LoadResource(ctx, &gen, true)
	spew.Dump(gen)

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

	res := rp.loadedResources["pfconfigdriver.PfConfGeneral"]
	if !res.IsValid(ctx) {
		t.Error("Resource isn't valid although it was just loaded")
	}

	os.Chtimes(res.controlFile(), time.Now(), time.Now())

	if res.IsValid(ctx) {
		t.Error("Resource is valid although the control file was just touched")
	}
}
