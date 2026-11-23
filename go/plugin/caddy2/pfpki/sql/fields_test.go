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

type secretTestClass struct {
	Name string `json:"name,omitempty"`
	Pin  string `json:"pin,omitempty" search:"-"`
}

// A field tagged search:"-" can be selected but not filtered or sorted
// on, so a starts_with search can't recover it.
func TestSecretFieldsNotSearchable(t *testing.T) {
	if got, want := SearchableFields(secretTestClass{}), []string{"id", "name"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("SearchableFields = %v, want %v", got, want)
	}
	if got, want := SqlFields(secretTestClass{}), []string{"id", "name", "pin"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("SqlFields = %v, want %v", got, want)
	}
	if _, err := (Search{Field: "pin", Op: "starts_with", Value: "1"}).SqlWhere(secretTestClass{}); err == nil {
		t.Error("Search.SqlWhere accepted the pin field")
	}
	if _, err := (Search{Field: "name", Op: "starts_with", Value: "1"}).SqlWhere(secretTestClass{}); err != nil {
		t.Errorf("Search.SqlWhere on name: %v", err)
	}
	if _, err := (Vars{Sort: []string{"pin"}}).SqlOrder(secretTestClass{}); err == nil {
		t.Error("Vars.SqlOrder accepted the pin field")
	}
	if _, err := (&Vars2{Sort: []string{"PIN desc"}}).SqlOrder(secretTestClass{}); err == nil {
		t.Error("Vars2.SqlOrder accepted the pin field")
	}
	if _, err := (&SearchStartsWithOp{Field: "pin", Value: "1"}).SqlWhere(secretTestClass{}); err == nil {
		t.Error("SearchStartsWithOp accepted the pin field")
	}
}
