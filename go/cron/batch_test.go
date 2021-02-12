package maint

import (
    "testing"
    "context"
    "time"
)

func TestBatch(t *testing.T) {
    sql := `DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT `
    count, err := BatchSql(
        context.Background(),
        time.Second,
        sql,
        []interface{}{time.Now(), 10 }...,
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
        []interface{}{time.Now(), 10 }...,
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
