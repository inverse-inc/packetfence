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

// sharedConnPool wraps the shared *sql.DB so that gorm.DB.DB() cannot return
// it. Every method GORM needs (queries, statements, BeginTx, Ping, Conn) is
// promoted from the embedded *sql.DB.
//
// Hiding it matters because gorm.Open Closes the pool when its dialector fails
// to initialize (the mysql dialector runs SELECT VERSION(), which fails while
// the database is down): on a raw *sql.DB that would close the pool for every
// holder in the process, permanently. It also stops callers from doing
// DB().Close() themselves.
type sharedConnPool struct {
	*sql.DB
}

// GetDBConn makes gorm.DB.DB() fail instead of reaching the shared pool.
func (sharedConnPool) GetDBConn() (*sql.DB, error) {
	return nil, errSharedPool
}

var cache = struct {
	mu  sync.Mutex
	dbs map[*sql.DB]*gorm.DB
}{dbs: map[*sql.DB]*gorm.DB{}}

// FromConfig returns the process-wide GORM handle for the configured database.
// It is safe for concurrent use and shared with every other caller: never
// Close its pool.
//
// Errors wrapping db.ErrInvalidConfig are hard configuration errors that
// retrying cannot fix. Any other error means the database could not be reached
// (gorm.Open queries the server version); it is not cached, so retry later.
// Once a handle is returned it reconnects on its own and needs no pinging.
func FromConfig(ctx context.Context) (*gorm.DB, error) {
	sqlDB, err := db.DbFromConfig(ctx)
	if err != nil {
		return nil, err
	}
	return forPool(sqlDB, db.ReturnURIFromConfig(ctx))
}

// forPool returns the GORM handle for sqlDB, opening it on first use. dsn is
// only parsed for its settings (e.g. time location); no connection is opened
// from it.
//
// The lock is held across gorm.Open, which runs one query. That query is
// bounded by the DSN's connect timeout, and concurrent callers would only
// repeat it.
func forPool(sqlDB *sql.DB, dsn string) (*gorm.DB, error) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	if gdb, ok := cache.dbs[sqlDB]; ok {
		return gdb, nil
	}

	gdb, err := gorm.Open(mysql.New(mysql.Config{
		DriverName: sqlcomment.DriverName,
		DSN:        dsn,
		Conn:       sharedConnPool{sqlDB},
	}), &gorm.Config{})
	if err != nil {
		return nil, err
	}
	cache.dbs[sqlDB] = gdb
	return gdb, nil
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
