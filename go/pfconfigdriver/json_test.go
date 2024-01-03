package pfconfigdriver

import (
	"bytes"
	"encoding/json"
	"testing"
)

func TestJsonMarshalJson(t *testing.T) {
	val := PfInt(10)
	data, err := json.Marshal(val)
	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	}

	if bytes.Compare(data, []byte("10")) != 0 {
		t.Fatalf("Not marshaled properly")
	}

	err = json.Unmarshal([]byte(`"11"`), &val)
	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	}

	err = json.Unmarshal([]byte(`"11"`), &val)
	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	}

	if int(val) != 11 {
		t.Fatalf("Expected 11 got %d", int(val))
	}
}
