package sql

import (
	"reflect"
	"testing"
)

type fieldsTestClass struct {
	ID    uint   `json:"-"`
	Name  string `json:"name,omitempty"`
	URL   string `json:"url,omitempty"`
	Other string `json:"other"`
}

// Building a SELECT or ORDER BY must not change the fields of the class
// for the next requests (SqlFields is cached per type).
func TestSqlFieldsNotModifiedByQueries(t *testing.T) {
	want := []string{"id", "name", "url", "other"}
	vars := Vars{Fields: []string{"url", "name"}, Sort: []string{"other desc", "name"}}
	for i := 0; i < 3; i++ {
		if _, err := vars.SqlSelect(fieldsTestClass{}); err != nil {
			t.Fatal(err)
		}
		if _, err := vars.SqlOrder(fieldsTestClass{}); err != nil {
			t.Fatal(err)
		}
		if got := SqlFields(fieldsTestClass{}); !reflect.DeepEqual(got, want) {
			t.Fatalf("after %d queries SqlFields = %v, want %v", i+1, got, want)
		}
	}
}
