package sql

import (
	"net/http/httptest"
	"strings"
	"testing"
)

type var2TestClass struct {
	ID        int    `json:"id"`
	CreatedAt string `json:"created_at"`
}

// A search without a query has no condition (#9564): it used to call
// SqlWhere on the nil SearchOp and panic.
func TestVars2SqlWithoutQuery(t *testing.T) {
	for _, body := range []string{`{}`, `{"limit":5}`, `{"limit":5,"cursor":10}`} {
		vars, err := VarsFromHttpRequest(httptest.NewRequest("POST", "/", strings.NewReader(body)))
		if err != nil {
			t.Fatalf("%s: decoding: %s", body, err)
		}
		sql, err := vars.Sql(var2TestClass{})
		if err != nil {
			t.Fatalf("%s: unexpected error: %s", body, err)
		}
		if sql.Where.Query != "" || len(sql.Where.Values) != 0 {
			t.Errorf("%s: expected no condition, got %q %v", body, sql.Where.Query, sql.Where.Values)
		}
	}
}

// A query still gives its condition
func TestVars2SqlWithQuery(t *testing.T) {
	body := `{"limit":5,"query":{"op":"and","values":[{"field":"id","op":"equals","value":3}]}}`
	vars, err := VarsFromHttpRequest(httptest.NewRequest("POST", "/", strings.NewReader(body)))
	if err != nil {
		t.Fatalf("decoding: %s", err)
	}
	sql, err := vars.Sql(var2TestClass{})
	if err != nil {
		t.Fatalf("unexpected error: %s", err)
	}
	if sql.Where.Query == "" || len(sql.Where.Values) != 1 {
		t.Fatalf("expected the id condition, got %q %v", sql.Where.Query, sql.Where.Values)
	}
}
