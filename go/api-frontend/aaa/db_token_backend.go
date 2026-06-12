package aaa

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/VividCortex/mysqlerr"
	"github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
)

type DbTokenBackend struct {
	sync.Mutex
	maxExpiration     time.Duration
	inActivityTimeout time.Duration
	Db                *sql.DB
}

func NewDbTokenBackend(expiration time.Duration, maxExpiration time.Duration, args []string) TokenBackend {
	return &DbTokenBackend{
		inActivityTimeout: expiration,
		maxExpiration:     maxExpiration,
	}
}

func timeToExpired(t time.Time) float64 {
	return float64(t.UnixMicro()) / 1000000.0
}

const sqlInsert = "INSERT INTO chi_cache ( `key`, `value`, `expires_at`) VALUES ( ?, ?, ? ) ON DUPLICATE KEY UPDATE value=VALUES(value), expires_at=VALUES(expires_at);"

func (tb *DbTokenBackend) Type() string {
	return "db"
}

func (tb *DbTokenBackend) getDB() (*sql.DB, error) {
	tb.Lock()
	defer tb.Unlock()

	if tb.Db != nil && tb.Db.Ping() == nil {
		return tb.Db, nil
	}

	tb.Db = nil

	var ctx = context.Background()
	ctx = log.LoggerNewContext(ctx)

	Database, err := db.DbFromConfig(ctx)
	if err != nil {
		fmt.Println("Unable to create DB connection from config:", err)
		return nil, err
	}

	err = Database.Ping()
	if err != nil {
		fmt.Println("Unable to connect to DB:", err)
		return nil, err
	}

	tb.Db = Database
	return Database, nil
}

func (tb *DbTokenBackend) TokenInfoForToken(token string) (*TokenInfo, time.Time) {
	expires := timeToExpired(time.Now())
	data := []byte{}
	expiresAt := float64(0)
	db, err := tb.getDB()
	if err != nil {
		return nil, time.Unix(0, 0)
	}
	row := db.QueryRow(
		"SELECT value, expires_at FROM chi_cache WHERE `key` = ? AND expires_at >= ?",
		tokenKey(tb, token),
		expires,
	)

	if err := row.Scan(&data, &expiresAt); err != nil {
		return nil, time.Unix(0, 0)
	}

	ti := TokenInfo{}
	err = json.Unmarshal([]byte(data), &ti)
	if err != nil {
		return nil, time.Unix(0, 0)
	}

	expiration := time.UnixMicro(int64(expiresAt * 1000000.0))

	return ValidTokenExpiration(&ti, expiration, tb.maxExpiration)
}

func (tb *DbTokenBackend) StoreTokenInfo(token string, ti *TokenInfo) error {
	ti.CreatedAt = time.Now()
	data, err := json.Marshal(ti)
	if err != nil {
		return err
	}

	expired := timeToExpired(time.Now().Add(tb.inActivityTimeout))
	db, err := tb.getDB()
	if err != nil {
		return err
	}
	_, err = db.Exec(
		sqlInsert,
		tokenKey(tb, token),
		data,
		expired,
	)

	return err
}

func (tb *DbTokenBackend) TokenIsValid(token string) bool {
	count := 0
	expired := timeToExpired(time.Now())
	db, err := tb.getDB()
	if err != nil {
		return false
	}
	row := db.QueryRow(
		"SELECT COUNT(*) FROM chi_cache WHERE `key` = ? AND expires_at >= ?",
		tokenKey(tb, token),
		expired,
	)

	if err := row.Scan(&count); err != nil {
		return false
	}

	return count == 1
}

// touchGranularity bounds how often a token's sliding expiration is rewritten.
func touchGranularity(timeout time.Duration) time.Duration {
	g := timeout / 10
	if g > time.Minute {
		g = time.Minute
	}
	if g < time.Second {
		// A zero/tiny timeout would otherwise degrade to one write per
		// request and, with Truncate(0) being a no-op, an instant expiry.
		g = time.Second
	}
	return g
}

// isRetryableTouchErr matches the Galera write-conflict class: a concurrent
// touch of the same token from another cluster node surfaces as a deadlock
// (certification failure / brute-force abort) or, when stuck behind an
// applier, a lock wait timeout.
func isRetryableTouchErr(err error) bool {
	var mysqlErr *mysql.MySQLError
	return errors.As(err, &mysqlErr) &&
		(mysqlErr.Number == mysqlerr.ER_LOCK_DEADLOCK || mysqlErr.Number == mysqlerr.ER_LOCK_WAIT_TIMEOUT)
}

func (tb *DbTokenBackend) TouchTokenInfo(token string) {
	// The expiration is quantized to bucket boundaries and only written when
	// it actually advances: within a bucket every node computes the identical
	// target, so all but the first touch match zero rows, produce no Galera
	// writeset and cannot conflict — instead of one same-row UPDATE per
	// authenticated request from every cluster node. The effective inactivity
	// timeout becomes [timeout-g, timeout].
	g := touchGranularity(tb.inActivityTimeout)
	target := timeToExpired(time.Now().Add(tb.inActivityTimeout).Truncate(g))
	db, err := tb.getDB()
	if err != nil {
		log.Logger().Error(err.Error())
		return
	}
	const attempts = 2
	for attempt := 1; ; attempt++ {
		_, err = db.Exec(
			"UPDATE chi_cache SET expires_at = ? WHERE `key` = ? AND expires_at < ?",
			target,
			tokenKey(tb, token),
			target,
		)
		if err == nil {
			return
		}
		if !isRetryableTouchErr(err) || attempt >= attempts {
			break
		}
		// A concurrent touch from another node won the bucket; the re-run
		// serializes behind it and matches zero rows.
		log.Logger().Debug("retrying token touch after cluster write conflict: " + err.Error())
	}
	log.Logger().Error(err.Error())
}

func (tb *DbTokenBackend) AdminActionsForToken(ctx context.Context, token string) map[string]bool {
	return AdminActionsForToken(ctx, tb, token)
}

var _ TokenBackend = (*DbTokenBackend)(nil)
