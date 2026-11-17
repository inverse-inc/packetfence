package dbgorm

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"sync/atomic"
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

	if _, err := forPool(ctx, sqlDB, dsn); err == nil {
		t.Fatal("open against an unreachable database succeeded")
	}
	if err := sqlDB.PingContext(ctx); err != nil && strings.Contains(err.Error(), "database is closed") {
		t.Fatal("failed gorm open closed the shared pool")
	}

	cache.mu.Lock()
	e := cache.entries[sqlDB]
	cache.mu.Unlock()
	if e != nil && e.gdb != nil {
		t.Fatal("failed open was cached as a handle")
	}
}

// --- forPool concurrency and failure handling (no database needed) ---

func swapOpener(t *testing.T, f func(*sql.DB, string) (*gorm.DB, error)) {
	t.Helper()
	old := openGorm
	openGorm = f
	t.Cleanup(func() { openGorm = old })
}

func swapClock(t *testing.T, f func() time.Time) {
	t.Helper()
	old := now
	now = f
	t.Cleanup(func() { now = old })
}

// freshPool returns a pool no other test has used, so cache entries don't leak
// between tests. sql.Open does no I/O.
func freshPool(t *testing.T) *sql.DB {
	t.Helper()
	sqlDB, err := db.ConnectURI(context.Background(), db.ReturnURI(context.Background(), "pf", "secret", "127.0.0.1", "1", t.Name()))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sqlDB.Close() })
	return sqlDB
}

// Request handlers resolve the handle per request, so while the database is
// down many requests miss at once. They must share one open attempt instead
// of each paying a connect timeout behind a lock.
func TestForPoolSharesOneOpenAttempt(t *testing.T) {
	var calls atomic.Int32
	release := make(chan struct{})
	want := &gorm.DB{}
	swapOpener(t, func(*sql.DB, string) (*gorm.DB, error) {
		calls.Add(1)
		<-release
		return want, nil
	})
	sqlDB := freshPool(t)

	const n = 20
	var wg sync.WaitGroup
	got := make([]*gorm.DB, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			got[i], _ = forPool(context.Background(), sqlDB, "")
		}(i)
	}
	// Let every goroutine reach forPool before the open completes.
	time.Sleep(50 * time.Millisecond)
	close(release)
	wg.Wait()

	if c := calls.Load(); c != 1 {
		t.Fatalf("open attempted %d times, want 1", c)
	}
	for i, g := range got {
		if g != want {
			t.Fatalf("caller %d got %v", i, g)
		}
	}
	// Later calls are cache hits.
	if g, err := forPool(context.Background(), sqlDB, ""); g != want || err != nil || calls.Load() != 1 {
		t.Fatalf("cached lookup: %v, %v, calls=%d", g, err, calls.Load())
	}
}

// After a failed open, callers get the same error without a new attempt until
// the backoff passes, so a dead database costs one connect attempt per backoff
// window rather than one per request.
func TestForPoolBacksOffAfterFailure(t *testing.T) {
	var calls atomic.Int32
	down := errors.New("connection refused")
	swapOpener(t, func(*sql.DB, string) (*gorm.DB, error) {
		calls.Add(1)
		return nil, down
	})
	clock := time.Unix(1000, 0)
	swapClock(t, func() time.Time { return clock })
	sqlDB := freshPool(t)
	ctx := context.Background()

	if _, err := forPool(ctx, sqlDB, ""); !errors.Is(err, down) {
		t.Fatalf("first call: %v", err)
	}
	if _, err := forPool(ctx, sqlDB, ""); !errors.Is(err, down) || calls.Load() != 1 {
		t.Fatalf("within backoff: %v, calls=%d", err, calls.Load())
	}

	clock = clock.Add(openRetryBackoff)
	want := &gorm.DB{}
	swapOpener(t, func(*sql.DB, string) (*gorm.DB, error) {
		calls.Add(1)
		return want, nil
	})
	if g, err := forPool(ctx, sqlDB, ""); g != want || err != nil || calls.Load() != 2 {
		t.Fatalf("after backoff: %v, %v, calls=%d", g, err, calls.Load())
	}
}

// A request waiting on someone else's open attempt must give up when its own
// context ends rather than hang with it.
func TestForPoolWaiterHonoursContext(t *testing.T) {
	release := make(chan struct{})
	swapOpener(t, func(*sql.DB, string) (*gorm.DB, error) {
		<-release
		return nil, errors.New("connection refused")
	})
	sqlDB := freshPool(t)

	holderDone := make(chan struct{})
	go func() { // holds the open attempt
		defer close(holderDone)
		forPool(context.Background(), sqlDB, "")
	}()
	// Registered after swapOpener, so it runs first: the holder must be done
	// with openGorm before the opener is restored.
	t.Cleanup(func() { close(release); <-holderDone })
	time.Sleep(20 * time.Millisecond)

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	start := time.Now()
	if _, err := forPool(ctx, sqlDB, ""); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("waiter: %v", err)
	}
	if d := time.Since(start); d > time.Second {
		t.Fatalf("waiter took %v", d)
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

// Known limitation, pinned so the package comment stays honest: inside a
// transaction gorm.DB.DB() unwraps the *sql.Tx by reflection and returns the
// shared pool, which the wrapper cannot intercept. Closing it there would
// close it for the whole process.
func TestTransactionDBExposesSharedPool(t *testing.T) {
	if os.Getenv("PFCONFIG_TESTING") == "" {
		t.Skip("run under pf-go-test.sh to exercise a real database")
	}
	ctx := context.Background()
	gdb, err := FromConfig(ctx)
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, err := db.DbFromConfig(ctx)
	if err != nil {
		t.Fatal(err)
	}
	var inTx *sql.DB
	if err := gdb.Transaction(func(tx *gorm.DB) error {
		inTx, err = tx.DB()
		return err
	}); err != nil {
		t.Fatal(err)
	}
	if inTx != sqlDB {
		t.Fatalf("tx.DB() = %p, want the shared pool %p; update the sharedConnPool comment", inTx, sqlDB)
	}
}

// Known limitation: gorm.DB.Connection needs the *sql.DB from DB(), which the
// wrapper refuses, so it is unsupported on these handles.
func TestConnectionUnsupported(t *testing.T) {
	if os.Getenv("PFCONFIG_TESTING") == "" {
		t.Skip("run under pf-go-test.sh to exercise a real database")
	}
	gdb, err := FromConfig(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	err = gdb.Connection(func(*gorm.DB) error { return nil })
	if !errors.Is(err, errSharedPool) {
		t.Fatalf("Connection: %v, want errSharedPool", err)
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
