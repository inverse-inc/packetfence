package sql

import (
	"testing"

	"github.com/davecgh/go-spew/spew"
	jsonv2 "github.com/go-json-experiment/json"
)

func TestQuery(t *testing.T) {
	data := `
{
  "cursor": 0,
  "limit": 1000,
  "query": {
    "op": "and",
    "values": [
      {
        "field": "created_at",
        "op": "between",
        "values": [
          "'.$datum_start.'",
          "'.$datum_einde.'"
        ]
      }
    ]
  }
}
	 `
	var query Vars2
	err := jsonv2.Unmarshal(
		[]byte(data),
		&query,
		jsonv2.WithUnmarshalers(SearchOpUnmarshalers),
	)
	if err != nil {
		t.Fatalf("Unable to marshal %s", err.Error())
	}

	spew.Dump(&query)
}
