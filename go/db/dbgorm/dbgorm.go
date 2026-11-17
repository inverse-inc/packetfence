// Package dbgorm hands out GORM handles built on the process-wide shared pool
// from db.DbFromConfig. It is a separate package so the binaries that only
// need database/sql do not link GORM.
package dbgorm

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/db/sqlcomment"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var errSharedPool = errors.New("dbgorm: the shared pool is not exposed (it must never be closed); use db.DbFromConfig for *sql.DB access")

// sharedConnPool wraps the shared *sql.DB so that gorm.DB.DB() does not
// return it. Queries, statements, BeginTx, Ping and Conn are promoted from the
// embedded *sql.DB.
//
// The point is gorm.Open's failure path: when the mysql dialector's SELECT
// VERSION() fails (database down), gorm.Open Closes db.DB(). On a raw shared
// *sql.DB that would close the pool for every holder in the process,
// permanently. It also keeps plain DB().Close() calls away from it.
//
// Two known gaps, pinned by tests:
//   - Inside a transaction, gorm.DB.DB() unwraps the *sql.Tx by reflection and
//     DOES return the shared pool. Never Close what tx.DB() returns.
//   - gorm.DB.Connection() needs DB() and so fails with errSharedPool on these
//     handles; use a transaction or db.DbFromConfig(...).Conn instead.
type sharedConnPool struct {
	*sql.DB
}

// GetDBConn makes gorm.DB.DB() fail instead of reaching the shared pool.
func (sharedConnPool) GetDBConn() (*sql.DB, error) {
	return nil, errSharedPool
}

// openRetryBackoff is how long a failed open is remembered: callers in that
// window get the same error without a new attempt, so a dead database costs
// one connection attempt per window instead of one per request.
const openRetryBackoff = 2 * time.Second

// Swapped by tests.
var (
	now      = time.Now
	openGorm = func(sqlDB *sql.DB, dsn string) (*gorm.DB, error) {
		return gorm.Open(mysql.New(mysql.Config{
			DriverName: sqlcomment.DriverName,
			DSN:        dsn,
			Conn:       sharedConnPool{sqlDB},
		}), &gorm.Config{})
	}
)

// entry is the per-pool state. Exactly one of these holds at a time: gdb is
// set (opened), opening is non-nil (an attempt is in flight; it is closed when
// the attempt ends), or neither (never tried, or the last attempt failed with
// lastErr at failedAt).
type entry struct {
	gdb      *gorm.DB
	opening  chan struct{}
	lastErr  error
	failedAt time.Time
}

var cache = struct {
	mu      sync.Mutex
	entries map[*sql.DB]*entry
}{entries: map[*sql.DB]*entry{}}

// FromConfig returns the process-wide GORM handle for the configured database.
// It is safe for concurrent use and cheap once opened (a cached lookup), so
// request handlers can call it per request; doing so also picks up a DSN change
// in pfconfig. Never Close its pool.
//
// Errors wrapping db.ErrInvalidConfig are hard configuration errors. Any other
// error means the database could not be reached (gorm.Open queries the server
// version); call again later.
func FromConfig(ctx context.Context) (*gorm.DB, error) {
	// Build the DSN once so the pool and gorm's parsed settings come from the
	// same pfconfig read.
	dsn := db.ReturnURIFromConfig(ctx)
	sqlDB, err := db.CachedConnectURI(ctx, dsn)
	if err != nil {
		return nil, err
	}
	return forPool(ctx, sqlDB, dsn)
}

// forPool returns the GORM handle for sqlDB, opening it on first use. dsn is
// only parsed for its settings (e.g. time location); the connection comes from
// sqlDB.
//
// The lock is never held across the open, which does I/O with no read
// deadline. Concurrent callers share the in-flight attempt, and a caller whose
// ctx ends stops waiting for it.
func forPool(ctx context.Context, sqlDB *sql.DB, dsn string) (*gorm.DB, error) {
	for {
		cache.mu.Lock()
		e := cache.entries[sqlDB]
		if e == nil {
			e = &entry{}
			cache.entries[sqlDB] = e
		}
		switch {
		case e.gdb != nil:
			gdb := e.gdb
			cache.mu.Unlock()
			return gdb, nil
		case e.opening != nil:
			opening := e.opening
			cache.mu.Unlock()
			select {
			case <-opening:
				continue // re-read the outcome
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		case e.lastErr != nil && now().Sub(e.failedAt) < openRetryBackoff:
			err := e.lastErr
			cache.mu.Unlock()
			return nil, err
		}

		opening := make(chan struct{})
		e.opening = opening
		cache.mu.Unlock()

		gdb, err := openGorm(sqlDB, dsn)

		cache.mu.Lock()
		e.opening = nil
		if err != nil {
			e.lastErr, e.failedAt = err, now()
		} else {
			e.gdb, e.lastErr = gdb, nil
		}
		cache.mu.Unlock()
		close(opening)
		return gdb, err
	}
}

// WaitFromConfig calls FromConfig until the database answers, sleeping retry
// between attempts. It gives up at once on a hard configuration error
// (db.ErrInvalidConfig) and when ctx is done.
func WaitFromConfig(ctx context.Context, retry time.Duration) (*gorm.DB, error) {
	return waitFor(ctx, retry, func() (*gorm.DB, error) { return FromConfig(ctx) })
}

func waitFor(ctx context.Context, retry time.Duration, open func() (*gorm.DB, error)) (*gorm.DB, error) {
	for {
		gdb, err := open()
		if err == nil {
			return gdb, nil
		}
		if errors.Is(err, db.ErrInvalidConfig) {
			return nil, err
		}
		log.LoggerWContext(ctx).Warn("Database not reachable yet, retrying: " + err.Error())

		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(retry):
		}
	}
}
