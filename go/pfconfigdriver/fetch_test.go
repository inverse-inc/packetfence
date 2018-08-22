package pfconfigdriver

import (
	"context"
	"os"
	"os/exec"
	"testing"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

var ctx = log.LoggerNewContext(context.Background())

func TestFetchSocket(t *testing.T) {
	result := FetchSocket(ctx, `{"method":"element", "key":"resource::fqdn","encoding":"json"}`+"\n")
	expected := `{"element":"pf.pfdemo.org"}`
	if string(result) != expected {
		t.Errorf("Response payload isn't correct '%s' instead of '%s'", result, expected)
	}

	result = FetchSocket(ctx, `{"method":"element", "key":"vidange","encoding":"json"}`+"\n")
	expected = `{"error":"No valid element was found for query"}`
	if string(result) != expected {
		t.Errorf("Response payload isn't correct '%s' instead of '%s'", result, expected)
	}
}

func TestFetchDecodeSocket(t *testing.T) {
	general := PfConfGeneral{}
	FetchDecodeSocket(ctx, &general)

	if general.Domain != "pfdemo.org" {
		t.Error("PfConfGeneral wasn't fetched and parsed correctly")
		spew.Dump(general)
	}

	var sections PfconfigKeys
	sections.PfconfigNS = "config::Pf"
	FetchDecodeSocket(ctx, &sections)

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

	invalid := struct {
		StructConfig
		PfconfigMethod string `val:"hash_element"`
		PfconfigNS     string `val:"vidange"`
		PfconfigHashNS string `val:"vidange"`
	}{}

	err := FetchDecodeSocket(ctx, &invalid)

	if err == nil {
		t.Error("Invalid struct should have created an error in pfconfig driver but it didn't")
	}

	invalid2 := struct {
		StructConfig
		PfconfigMethod string `val:"vidange"`
		PfconfigNS     string `val:"vidange"`
		PfconfigHashNS string `val:"vidange"`
	}{}

	err = FetchDecodeSocket(ctx, &invalid2)

	if err == nil {
		t.Error("Invalid struct should have created an error in pfconfig driver but it didn't")
	}

	var i PfconfigObject

	i = &PfConfGeneral{}

	err = FetchDecodeSocket(ctx, i)

	if err != nil {
		t.Error("Failed to fetch from pfconfig with type being in an interface")
	}

}

func TestFetchDecodeSocketCache(t *testing.T) {
	gen := PfConfGeneral{}

	// Test loading a resource and validating the result
	loaded, err := FetchDecodeSocketCache(ctx, &gen)
	sharedutils.CheckTestError(t, err)

	if !loaded {
		t.Error("Resource wasn't loaded when calling a first time load")
	}

	expected := "pfdemo.org"
	if gen.Domain != expected {
		t.Errorf("Resource domain wasn't loaded correctly through resource pool. Got %s instead of %s", gen.Domain, expected)
	}

	if !(gen.GetLoadedAt().Year() > 0) {
		t.Error("Resource wasn't marked as loaded")
	}

	// Test loading a resource again which shouldn't read from pfconfig as it hasn't changed from when it was last read
	loaded, err = FetchDecodeSocketCache(ctx, &gen)
	sharedutils.CheckTestError(t, err)

	if loaded {
		t.Error("Resource was loaded again even though it was already loaded")
	}

	expected = "pfdemo.org"
	if gen.Domain != expected {
		t.Errorf("Resource domain wasn't loaded correctly. Got %s instead of %s", gen.Domain, expected)
	}

	// Test changing data in pfconfig and reloading the resource
	cmd := exec.Command("sed", "-i.bak", "s/domain=pfdemo.org/domain=zammitcorp.com/g", "/usr/local/pf/t/data/pf.conf")
	err = cmd.Run()
	sharedutils.CheckError(err)

	// Expire data in pfconfig
	FetchSocket(ctx, `{"method":"expire", "encoding":"json", "namespace":"config::Pf"}`+"\n")

	// Load the resource while accepting the reusal of the data already populated in the resource
	loaded, err = FetchDecodeSocketCache(ctx, &gen)
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

func TestArrayElements(t *testing.T) {
	var li ListenInts

	FetchDecodeSocket(ctx, &li)

	expected := 2
	if len(li.Element) != expected {
		t.Errorf("Wrong number of interfaces detected (%d instead of %d)", len(li.Element), expected)
	}

	expectedInts := []string{"eth1.1", "eth1.2"}
	for i, intName := range expectedInts {
		if li.Element[i] != intName {
			t.Errorf("Wrong value at position %d. Got %s instead of %s", i, li.Element[i], intName)
		}
	}
}

func TestDecodeInElement(t *testing.T) {
	var ar AdminRoles

	FetchDecodeSocket(ctx, &ar)

	val, found := ar.Element["ALL"]

	if !found {
		t.Error("Cannot find the decoded element")
	}

	if len(val.Actions) == 0 {
		t.Error("Actions are empty when they shouldn't be")
	}

}

func TestCreateQuery(t *testing.T) {
	general := PfConfGeneral{}

	query := createQuery(ctx, &general)

	// Test namespace that doesn't have the hostname overlay
	if query.ns != "config::Pf;general" {
		t.Error("Wrong namespace name out of createQuery", query.ns)
	}

	// Test enabling the overlay on non-enabled struct
	general.PfconfigHostnameOverlay = "yes"
	query = createQuery(ctx, &general)
	if query.ns != "config::Pf("+myHostname+");general" {
		t.Error("Wrong namespace name out of createQuery", query.ns)
	}

	// Test a struct that overrides the field
	mgmt := ManagementNetwork{}
	query = createQuery(ctx, &mgmt)
	if query.ns != "interfaces::management_network("+myHostname+")" {
		t.Error("Wrong namespace name out of createQuery", query.ns)
	}

	// Test requesting a hostname overlay manually
	general.PfconfigNS = "config::Pf(testing)"
	general.PfconfigHostnameOverlay = "yes"
	query = createQuery(ctx, &general)
	if query.ns != "config::Pf(testing);general" {
		t.Error("Wrong namespace name out of createQuery", query.ns)
	}
}

// fetches resource::fqdn requesting Sereal encoding for the reply
func BenchmarkFetchSocketSerealSimple(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"element", "key":"resource::fqdn"}`+"\n")
	}
}

// fetches resource::fqdn requesting JSON encoding for the reply
func BenchmarkFetchSocketJsonSimple(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"element", "key":"resource::fqdn", "encoding":"json"}`+"\n")
	}
}

// fetches interfaces requesting Sereal encoding for the reply
func BenchmarkFetchSocketSerealComplexWithToJson(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"element", "key":"interfaces"}`+"\n")
	}
}

// fetches interfaces requesting JSON encoding for the reply.
// Some of the objects of that namespace need to be transformed from Perl objects to JSON.
func BenchmarkFetchSocketJsonComplexWithToJson(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"element", "key":"interfaces", "encoding":"json"}`+"\n")
	}
}

// fetches config::Pf requesting Sereal encoding for the reply
func BenchmarkFetchSocketSerealComplex(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"element", "key":"config::Pf"}`+"\n")
	}
}

// fetches config::Pf requesting JSON encoding for the reply
func BenchmarkFetchSocketJsonComplex(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"element", "key":"config::Pf", "encoding":"json"}`+"\n")
	}
}

// fetches the subnamespace config::Pf;general requesting Sereal encoding for the reply
func BenchmarkFetchSocketSerealSubNamespace(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"hash_element", "key":"config::Pf;general"}`+"\n")
	}
}

// fetches the subnamespace config::Pf;general requesting JSON encoding for the reply.
func BenchmarkFetchSocketJsonSubNamespace(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FetchSocket(ctx, `{"method":"hash_element", "key":"config::Pf;general", "encoding":"json"}`+"\n")
	}
}
