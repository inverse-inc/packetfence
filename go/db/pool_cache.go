package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sync"
)

// ErrInvalidConfig marks errors from the cached constructors (DbFromConfig,
// ConnectDb, DbLocalFromConfig). Opening a pool does no network I/O, so these
// are DSN/driver errors that retrying cannot fix: callers should abort rather
// than loop. Database outages never carry it.
var ErrInvalidConfig = errors.New("invalid database configuration")

// poolCache holds one *sql.DB per DSN for the life of the process.
//
// A *sql.DB is a pool that reconnects on its own, so opening a new one never
// helps recover from an outage; callers that did so on a failed Ping leaked a
// pool (and its ProxySQL frontend slots) each time.
//
// Keys are full DSNs and contain the password: never log them.
//
// Pools for a DSN that is no longer configured (e.g. after a password change)
// are kept, not closed, since other holders may still use them; their idle
// connections drain via SetConnMaxIdleTime.
var poolCache = struct {
	mu    sync.Mutex
	pools map[string]*sql.DB
}{pools: map[string]*sql.DB{}}

// CachedConnectURI returns the shared pool for uri, opening it on first use.
// Never Close it. Prefer DbFromConfig; this is for callers that already built
// the DSN and need the pool for exactly that DSN.
//
// Errors are returned and never cached. sql.Open does no network I/O (it only
// parses the DSN through the driver's OpenConnector), so an error here is a
// hard configuration/driver error, not a transient one; holding the lock
// across it is cheap.
func CachedConnectURI(ctx context.Context, uri string) (*sql.DB, error) {
	poolCache.mu.Lock()
	defer poolCache.mu.Unlock()

	if db, ok := poolCache.pools[uri]; ok {
		return db, nil
	}

	db, err := ConnectURI(ctx, uri)
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrInvalidConfig, err)
	}
	poolCache.pools[uri] = db
	return db, nil
}
