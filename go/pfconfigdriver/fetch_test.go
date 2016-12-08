package pfconfigdriver

import (
	"github.com/davecgh/go-spew/spew"
	"testing"
)

func TestFetchSocket(t *testing.T) {
	result := fetchSocket(`{"method":"element", "key":"resource::fqdn","encoding":"json"}` + "\n")
	expected := `{"element":"pf-julien.inverse.ca"}`
	if string(result) != expected {
		t.Errorf("Response payload isn't correct '%s' instead of '%s'", result, expected)
	}
}

func TestFetchDecodeSocket(t *testing.T) {
	general := PfConfGeneral{}
	fetchDecodeSocket(&general)

	if general.Domain != "inverse.ca" {
		t.Error("PfConfGeneral wasn't fetched and parsed correctly")
		spew.Dump(general)
	}

}
