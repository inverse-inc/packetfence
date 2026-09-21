package models

import (
	"reflect"
	"testing"
)

// TestSerialCandidates covers the forms an external system (Intune,
// openssl output) may present a serial in; pki_certs stores decimal.
func TestSerialCandidates(t *testing.T) {
	cases := map[string][]string{
		"":                      nil,
		"12345":                 {"12345", "74565"},
		"1A2F":                  {"1A2F", "6703"},
		"0x1a2f":                {"0x1a2f", "6703"},
		"1a:2f":                 {"1a:2f", "6703"},
		"1A 2F":                 {"1A 2F", "6703"},
		"00ff":                  {"00ff", "255"},
		"not a serial":          {"not a serial"},
		"  42  ":                {"42", "66"},
		"123456789012345678901": {"123456789012345678901", "1375488932351661432080641"},
	}
	for in, want := range cases {
		if got := serialCandidates(in); !reflect.DeepEqual(got, want) {
			t.Errorf("%q: got %v want %v", in, got, want)
		}
	}
}
