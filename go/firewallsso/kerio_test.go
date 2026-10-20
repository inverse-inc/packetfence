package firewallsso

import (
	"encoding/json"
	"testing"
)

func TestKerioDefaultPort(t *testing.T) {
	fw := &Kerio{}
	if err := fw.initChild(ctx); err != nil {
		t.Fatalf("initChild returned an error: %s", err)
	}
	if fw.Port != "4081" {
		t.Errorf("Expected default Kerio port 4081, got %q", fw.Port)
	}
}

func TestKerioKeepsConfiguredPort(t *testing.T) {
	fw := &Kerio{Port: "4444"}
	if err := fw.initChild(ctx); err != nil {
		t.Fatalf("initChild returned an error: %s", err)
	}
	if fw.Port != "4444" {
		t.Errorf("Expected configured port 4444 to be kept, got %q", fw.Port)
	}
}

// The host id comes back as a JSON number and must be re-encoded as a bare
// number (not a quoted string) in ActiveHosts.login / .logout params.
func TestKerioHostIdEncoding(t *testing.T) {
	var hl kerioHostList
	if err := json.Unmarshal([]byte(`{"list":[{"id":42,"ip":"1.2.3.4"}],"totalItems":1}`), &hl); err != nil {
		t.Fatalf("could not decode host list: %s", err)
	}
	if len(hl.List) != 1 || hl.List[0].IP != "1.2.3.4" {
		t.Fatalf("unexpected decode: %+v", hl)
	}

	body, err := json.Marshal(map[string]interface{}{
		"hostId":   hl.List[0].ID,
		"userName": "lzammit@example.local",
	})
	if err != nil {
		t.Fatalf("could not encode login params: %s", err)
	}
	expected := `{"hostId":42,"userName":"lzammit@example.local"}`
	if string(body) != expected {
		t.Errorf("Unexpected login params.\n got: %s\nwant: %s", body, expected)
	}
}
