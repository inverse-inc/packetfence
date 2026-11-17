package api

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	_ "github.com/go-sql-driver/mysql"
)

// a handle that never connects: sql.Open does not
func unconnectedDB(t *testing.T) *sql.DB {
	t.Helper()
	database, err := sql.Open("mysql", "pf@tcp(127.0.0.1:1)/pf")
	if err != nil {
		t.Fatal(err)
	}
	return database
}

// a failed open leaves no handle, the next request tries again, and the
// handle is resolved on each use rather than pinned
func TestPluginDBReopenError(t *testing.T) {
	saved := sqlDBFromConfig
	defer func() { sqlDBFromConfig = saved }()

	h := &APIHandler{}
	database := unconnectedDB(t)
	calls := 0
	sqlDBFromConfig = func(ctx context.Context, _ ...string) (*sql.DB, error) {
		calls++
		if calls == 1 {
			return nil, errors.New("unreachable")
		}
		return database, nil
	}
	if got := h.pluginDB(context.Background()); got != nil {
		t.Fatalf("expected no handle, got %p", got)
	}
	if got := h.pluginDB(context.Background()); got != database {
		t.Fatalf("the second request did not get the handle, got %p", got)
	}
	if got := h.pluginDB(context.Background()); got != database {
		t.Fatalf("the third request did not get the handle, got %p", got)
	}
	if calls != 3 {
		t.Errorf("expected 3 lookups, got %d", calls)
	}
}
