package admin_api_audit_log

import (
	"testing"
)

func TestReplaceJson(t *testing.T) {
	j, err := MaskSecrets(`{"password":"blah"}`, "password")
	if err != nil {
		t.Fatalf("Cannot mask json error: %s", err.Error())
	}

	if j != `{"password":"**********"}` {
		t.Fatalf("json is not masked properly")
	}
}
