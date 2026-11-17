package dbgorm

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/db"
	"gorm.io/gorm"
)

// gorm.Open runs SELECT VERSION() and, if that fails, Closes the pool it was
// given. With the shared pool that would kill every holder's handle for the
// rest of the process, so a failed open must leave the pool usable.
func TestFailedOpenDoesNotCloseSharedPool(t *testing.T) {
	ctx := context.Background()
	// Nothing listens on port 1: the connection is refused immediately.
	dsn := db.ReturnURI(ctx, "pf", "secret", "127.0.0.1", "1", "pf")
	sqlDB, err := db.ConnectURI(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer sqlDB.Close()

	if _, err := forPool(sqlDB, dsn); err == nil {
		t.Fatal("open against an unreachable database succeeded")
	}
	if err := sqlDB.PingContext(ctx); err != nil && strings.Contains(err.Error(), "database is closed") {
		t.Fatal("failed gorm open closed the shared pool")
	}

	cache.mu.Lock()
	_, cached := cache.dbs[sqlDB]
	cache.mu.Unlock()
	if cached {
		t.Fatal("failed open was cached")
	}
}

func TestFromConfigLive(t *testing.T) {
	if os.Getenv("PFCONFIG_TESTING") == "" {
		t.Skip("run under pf-go-test.sh to exercise a real database")
	}
	ctx := context.Background()

	a, err := FromConfig(ctx)
	if err != nil {
		t.Fatalf("FromConfig: %v", err)
	}
	b, err := FromConfig(ctx)
	if err != nil {
		t.Fatalf("FromConfig: %v", err)
	}
	if a != b {
		t.Fatal("FromConfig returned two different handles")
	}

	sqlDB, err := db.DbFromConfig(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if pool, ok := a.ConnPool.(sharedConnPool); !ok || pool.DB != sqlDB {
		t.Fatal("gorm handle does not use the shared sql pool")
	}

	// The shared pool must not be reachable through gorm, or a caller could
	// Close it for everyone.
	if got, err := a.DB(); err == nil || got != nil {
		t.Fatal("gorm.DB.DB() exposed the shared pool")
	}

	var one int
	if err := a.Raw("SELECT 1").Scan(&one).Error; err != nil || one != 1 {
		t.Fatalf("query through shared pool: %v (%d)", err, one)
	}
	if err := a.Transaction(func(tx *gorm.DB) error {
		return tx.Exec("SELECT 1").Error
	}); err != nil {
		t.Fatalf("transaction through shared pool: %v", err)
	}
}

func TestWaitForRetriesTransientErrors(t *testing.T) {
	want := &gorm.DB{}
	calls := 0
	got, err := waitFor(context.Background(), time.Millisecond, func() (*gorm.DB, error) {
		calls++
		if calls < 3 {
			return nil, errors.New("connection refused")
		}
		return want, nil
	})
	if err != nil || got != want || calls != 3 {
		t.Fatalf("got %v, %v after %d calls", got, err, calls)
	}
}

func TestWaitForAbortsOnHardError(t *testing.T) {
	calls := 0
	_, err := waitFor(context.Background(), time.Millisecond, func() (*gorm.DB, error) {
		calls++
		return nil, fmt.Errorf("%w: bad dsn", db.ErrInvalidConfig)
	})
	if !errors.Is(err, db.ErrInvalidConfig) || calls != 1 {
		t.Fatalf("hard error was retried or lost: %v after %d calls", err, calls)
	}
}

func TestWaitForStopsOnCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	calls := 0
	_, err := waitFor(ctx, time.Hour, func() (*gorm.DB, error) {
		calls++
		cancel()
		return nil, errors.New("connection refused")
	})
	if !errors.Is(err, context.Canceled) || calls != 1 {
		t.Fatalf("cancel not honoured: %v after %d calls", err, calls)
	}
}
