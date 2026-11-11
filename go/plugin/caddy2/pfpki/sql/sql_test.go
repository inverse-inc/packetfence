package sql

import (
	"testing"
)

type sqlWhereTestClass struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

func TestSqlWhereUnknownField(t *testing.T) {
	unknown := Search{Field: "nope", Op: "equals", Value: 1}
	known := Search{Field: "id", Op: "equals", Value: 1}
	for name, search := range map[string]Search{
		"single condition": {Op: "and", Values: []Search{unknown}},
		"two conditions":   {Op: "and", Values: []Search{known, unknown}},
	} {
		if where, err := search.SqlWhere(sqlWhereTestClass{}); err == nil {
			t.Errorf("%s: an unknown field must be refused, got the query %q", name, where.Query)
		}
	}
}

func TestSqlWhereSingleCondition(t *testing.T) {
	search := Search{Op: "and", Values: []Search{{Field: "name", Op: "equals", Value: "bob"}}}
	where, err := search.SqlWhere(sqlWhereTestClass{})
	if err != nil {
		t.Fatalf("unexpected error: %s", err)
	}
	if where.Query != "`name` = ?" || len(where.Values) != 1 || where.Values[0] != "bob" {
		t.Fatalf("unexpected where clause: %q %v", where.Query, where.Values)
	}
}
