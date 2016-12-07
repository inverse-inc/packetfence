package pfconfigdriver

import (
	"testing"
)

func TestFetchSocket(t *testing.T) {
	result := fetchSocket(`{"method":"element", "key":"resource::fqdn","encoding":"json"}` + "\n")
	expected := `{"element":"pf-julien.inverse.ca"}`
	if string(result) != expected {
		t.Errorf("Response payload isn't correct '%s' instead of '%s'", result, expected)
	}
}
