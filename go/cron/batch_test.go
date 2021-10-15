package maint

import (
	"context"
	"testing"
	"time"
)

func runStatements(t *testing.T, statements []string) {
	db, err := getDb()
	if err != nil {
		t.Fatal("Cannot connect to db error", err.Error())
	}

	for _, sql := range statements {
		_, err = db.Exec(sql)
		if err != nil {
			t.Fatalf("Invalid SQL '%s': %s", sql, err.Error())
		}
	}

}

type sqlCountTest struct {
	name          string
	sql           string
	expectedCount int
}

func testSqlCountTests(t *testing.T, tests []sqlCountTest) {
	db, err := getDb()
	if err != nil {
		t.Fatal("Cannot connect to db error", err.Error())
	}

	for _, test := range tests {
		count := 0
		if err = db.QueryRow(test.sql).Scan(&count); err != nil {
			t.Fatal(err.Error())
		}

		if count != test.expectedCount {
			t.Fatalf("%s: found %d entries instead of %d", test.name, count, test.expectedCount)
		}
	}
}

func TestBatch(t *testing.T) {
	sql := `DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT `
	count, err := BatchSql(
		context.Background(),
		time.Second,
		sql,
		[]interface{}{time.Now(), 10}...,
	)

	if err == nil {
		t.Errorf("Expected an error got none")
	}
	if count != -1 {
		t.Errorf("Expected an invalid count count %d", count)
	}

	sql = `DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`
	count, err = BatchSql(
		context.Background(),
		time.Second,
		sql,
		[]interface{}{time.Now(), 10}...,
	)

	if err == nil {
		t.Errorf("Expected an error got none")
	}
	if count != 0 {
		t.Errorf("Expected an invalid count count %d", count)
	}

	db, err := getDb()
	if err != nil {
		t.Fatal("Cannot connect to db error", err.Error())
	}

	db.Exec("DELETE FROM admin_api_audit_log;")
	db.Exec("INSERT INTO admin_api_audit_log (request, status) VALUES ('', 200);")

	sql = `DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`
	count, err = BatchSql(
		context.Background(),
		0,
		sql,
		[]interface{}{time.Now(), 60, 1}...,
	)

	if err != nil {
		t.Errorf("Got an error %s", err.Error())
	}

	if count != 0 {
		t.Errorf("Expected an invalid count count %d", count)
	}

	count, err = BatchSql(
		context.Background(),
		0,
		sql,
		[]interface{}{time.Now(), 0, 1}...,
	)

	if err != nil {
		t.Errorf("Got an error %s", err.Error())
	}

	if count != 1 {
		t.Errorf("Expected an invalid count count %d", count)
	}
}
