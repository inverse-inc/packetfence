package api

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"testing"
	"time"

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

// a slow reopen of the database does not block the handlers that read the
// handle, and two requests at once open it once
func TestPluginDBReopen(t *testing.T) {
	saved := openPluginDB
	defer func() { openPluginDB = saved }()

	h := &APIHandler{}
	release := make(chan struct{})
	opened := make(chan *sql.DB, 2)
	openPluginDB = func(ctx context.Context, _ ...string) (*sql.DB, error) {
		<-release
		database := unconnectedDB(t)
		opened <- database
		return database, nil
	}

	var wg sync.WaitGroup
	results := make([]*sql.DB, 2)
	for i := range results {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results[i] = h.pluginDB(context.Background())
		}(i)
	}

	// while both are connecting, sqlDB answers at once
	done := make(chan struct{})
	go func() {
		h.sqlDB()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("sqlDB blocked while the plugins database was opened")
	}

	close(release)
	wg.Wait()
	if results[0] == nil || results[0] != results[1] || h.sqlDB() != results[0] {
		t.Fatalf("expected one handle for both requests, got %p %p (stored %p)", results[0], results[1], h.sqlDB())
	}
	close(opened)
	if n := len(opened); n != 1 {
		t.Errorf("the database was opened %d times, expected once", n)
	}
}

// a failed reopen leaves the handle unset, the next request tries again
func TestPluginDBReopenError(t *testing.T) {
	saved := openPluginDB
	defer func() { openPluginDB = saved }()

	h := &APIHandler{}
	calls := 0
	openPluginDB = func(ctx context.Context, _ ...string) (*sql.DB, error) {
		calls++
		if calls == 1 {
			return nil, errors.New("unreachable")
		}
		return unconnectedDB(t), nil
	}
	if database := h.pluginDB(context.Background()); database != nil {
		t.Fatalf("expected no handle, got %p", database)
	}
	if database := h.pluginDB(context.Background()); database == nil || h.sqlDB() != database {
		t.Fatal("the second request did not store the handle")
	}
	if calls != 2 {
		t.Errorf("expected 2 opens, got %d", calls)
	}
}
