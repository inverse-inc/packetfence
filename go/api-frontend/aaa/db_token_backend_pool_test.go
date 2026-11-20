package aaa

import (
	"context"
	"database/sql"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/db"
)

// The backend must resolve the pool on every use instead of pinning the first
// one, so a database DSN change in pfconfig (password, host) takes effect
// without a restart. Pools are cached per DSN, so this is a map lookup.
func TestDbTokenBackendPicksUpPoolChanges(t *testing.T) {
	ctx := context.Background()
	open := func(name string) *sql.DB {
		p, err := db.ConnectURI(ctx, db.ReturnURI(ctx, "pf", "secret", "127.0.0.1", "1", name))
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { p.Close() })
		return p
	}
	first, second := open("token_a"), open("token_b")

	current := first
	old := dbFromConfig
	dbFromConfig = func(context.Context, ...string) (*sql.DB, error) { return current, nil }
	t.Cleanup(func() { dbFromConfig = old })

	tb := NewDbTokenBackend(time.Minute, time.Hour, nil).(*DbTokenBackend)
	if got, err := tb.getDB(); err != nil || got != first {
		t.Fatalf("first getDB = %p, %v; want %p", got, err, first)
	}
	current = second
	if got, err := tb.getDB(); err != nil || got != second {
		t.Fatalf("after config change getDB = %p, %v; want %p", got, err, second)
	}
}
