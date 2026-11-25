package manager

import (
	"reflect"
	"testing"

	ns "github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/namespace"
)

func testHash() *ns.HashData {
	return &ns.HashData{
		SectionsOrdered: []string{"a", "10.0.0.1", "my-switch"},
		Sections: map[string]map[string]string{
			"a":         {"ip": "1"},
			"10.0.0.1":  {"ip": "2"},
			"my-switch": {"ip": "3"},
		},
	}
}

func TestExtractQuery(t *testing.T) {
	tests := []struct {
		in   string
		want Query
	}{
		{"config::Switch", Query{Namespace: "config::Switch", CacheKey: "config::Switch"}},
		{"config::Switch()", Query{Namespace: "config::Switch", CacheKey: "config::Switch"}},
		{"config::Switch();10.0.0.1", Query{Namespace: "config::Switch", Key: "10.0.0.1", CacheKey: "config::Switch"}},
		{"config::Switch();my switch-1/2", Query{Namespace: "config::Switch", Key: "my switch-1/2", CacheKey: "config::Switch"}},
		{"config::Switch(arg1,arg2);k", Query{Namespace: "config::Switch", Overlay: "arg1,arg2", Key: "k", CacheKey: "config::Switch(arg1,arg2)"}},
		{"resource::array();0", Query{Namespace: "resource::array", Key: "0", CacheKey: "resource::array"}},
	}
	for _, tt := range tests {
		got, err := ExtractQuery(tt.in)
		if err != nil {
			t.Fatalf("ExtractQuery(%q): %v", tt.in, err)
		}
		if got != tt.want {
			t.Errorf("ExtractQuery(%q) = %+v, want %+v", tt.in, got, tt.want)
		}
	}
	for _, bad := range []string{"", ";key", "config::Switch(;k"} {
		if _, err := ExtractQuery(bad); err == nil {
			t.Errorf("ExtractQuery(%q) should fail", bad)
		}
	}
}

// The Perl client walks a tied hash with next_key, passing the previous key in last_key.
func TestNextKeyIteratesAllKeys(t *testing.T) {
	conf := testHash()
	var got []string
	last := ""
	for i := 0; i < 10; i++ {
		r, err := nextKey(Request{Key: "config::Switch()", LastKey: last}, conf)
		if err != nil {
			t.Fatal(err)
		}
		k := r.(map[string]any)["next_key"]
		if k == nil {
			break
		}
		last = k.(string)
		got = append(got, last)
	}
	if !reflect.DeepEqual(got, conf.SectionsOrdered) {
		t.Fatalf("iterated keys %v, want %v", got, conf.SectionsOrdered)
	}
}

func TestNextKeyEmptyHash(t *testing.T) {
	r, err := nextKey(Request{Key: "config::Switch()"}, &ns.HashData{Sections: map[string]map[string]string{}})
	if err != nil {
		t.Fatal(err)
	}
	if r.(map[string]any)["next_key"] != nil {
		t.Fatalf("expected nil next_key, got %v", r)
	}
}

// The Perl client sends the searched key in "search", the key field holds the namespace.
func TestKeyExistsUsesSearch(t *testing.T) {
	r, err := keyExists(Request{Key: "config::Switch()", Search: "10.0.0.1"}, testHash())
	if err != nil {
		t.Fatal(err)
	}
	if r.(map[string]int)["result"] != 1 {
		t.Fatalf("key should exist, got %v", r)
	}
	r, _ = keyExists(Request{Key: "config::Switch()", Search: "nope"}, testHash())
	if r.(map[string]int)["result"] != 0 {
		t.Fatalf("key should not exist, got %v", r)
	}
}

// Perl answers an unknown key with no element (undef for the client), not an error.
func TestHashElementMissingKeyIsUndef(t *testing.T) {
	r, err := hashElement(Request{Key: "config::Switch();nope"}, testHash())
	if err != nil {
		t.Fatalf("missing key must not be an error: %v", err)
	}
	if v, ok := r.(map[string]any)["element"]; ok && v != nil {
		t.Fatalf("expected no element, got %v", v)
	}
	r, _ = hashElement(Request{Key: "config::Switch();10.0.0.1"}, testHash())
	if !reflect.DeepEqual(r.(map[string]any)["element"], map[string]string{"ip": "2"}) {
		t.Fatalf("bad element %v", r)
	}
}

// The Perl client sends the array index in the key (NS;INDEX), not in "index".
func TestArrayElementIndexFromKey(t *testing.T) {
	conf := &ns.ArrayData{Values: []string{"zero", "one"}}
	r, err := arrayElement(Request{Key: "resource::array();1"}, conf)
	if err != nil {
		t.Fatal(err)
	}
	if r.(map[string]any)["element"] != "one" {
		t.Fatalf("expected one, got %v", r)
	}
}

// A method used on the wrong namespace type must not panic (it would kill the daemon).
func TestWrongTypeDoesNotPanic(t *testing.T) {
	scalar := &ns.ScalarData{Value: "x"}
	for name, fn := range methodsFuncs {
		if name == "expire" || name == "element" {
			continue
		}
		func() {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("%s panicked on a scalar namespace: %v", name, r)
				}
			}()
			_, _ = fn(Request{Key: "resource::Test()"}, scalar)
		}()
	}
}
