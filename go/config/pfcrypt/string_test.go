package pfcrypt

import (
	"bytes"
	"encoding/json"
	"testing"

	"github.com/google/go-cmp/cmp"
)

type testJson struct {
	F1 CryptString
	F2 string
}

func TestString(t *testing.T) {
	data := testJson{"Value1", "Value2"}
	out, err := json.Marshal(&data)
	if err != nil {
		t.Fatalf("%s", err.Error())
	}

	if !bytes.Contains(out, []byte(PREFIX)) {
		t.Fatalf("%s does not contain encrypted data", string(out))
	}

	got := testJson{}
	if err = json.Unmarshal(out, &got); err != nil {
		t.Fatalf("%s", err.Error())
	}

	if diff := cmp.Diff(data, got); diff != "" {
		t.Fatalf("Did not match %s", diff)
	}

	if err = json.Unmarshal([]byte(`{"F1":"Value1","F2":"Value2"}`), &got); err != nil {
		t.Fatalf("%s", err.Error())
	}

	if diff := cmp.Diff(data, got); diff != "" {
		t.Fatalf("Did not match %s", diff)
	}

}
