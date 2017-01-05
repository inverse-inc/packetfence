package pfconfigdriver

import (
	"context"
	"github.com/davecgh/go-spew/spew"
	"testing"
)

var ctx = context.Background()

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
	FetchDecodeSocketStruct(ctx, &general)

	if general.Domain != "pfdemo.org" {
		t.Error("PfConfGeneral wasn't fetched and parsed correctly")
		spew.Dump(general)
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

	invalid := struct {
		PfconfigMethod string `val:"hash_element"`
		PfconfigNS     string `val:"vidange"`
		PfconfigHashNS string `val:"vidange"`
	}{}

	err := FetchDecodeSocketStruct(ctx, &invalid)

	if err == nil {
		t.Error("Invalid struct should have created an error in pfconfig driver but it didn't")
	}

	invalid2 := struct {
		PfconfigMethod string `val:"vidange"`
		PfconfigNS     string `val:"vidange"`
		PfconfigHashNS string `val:"vidange"`
	}{}

	err = FetchDecodeSocketStruct(ctx, &invalid2)

	if err == nil {
		t.Error("Invalid struct should have created an error in pfconfig driver but it didn't")
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
