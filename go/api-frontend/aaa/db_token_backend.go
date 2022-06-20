package aaa

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
)

type DbTokenBackend struct {
	maxExpiration     time.Duration
	inActivityTimeout time.Duration
	Db                *sql.DB
}

func NewDbTokenBackend(expiration time.Duration, maxExpiration time.Duration, args []string) *DbTokenBackend {
	return &DbTokenBackend{
		Db:                getDB(),
		inActivityTimeout: expiration,
		maxExpiration:     maxExpiration,
	}
}

func timeToExpired(t time.Time) float64 {
	return float64(t.UnixMicro()) / 1000000.0
}

const sqlInsert = "INSERT INTO chi_cache ( `key`, `value`, `expires_at`) VALUES ( ?, ?, ? ) ON DUPLICATE KEY UPDATE value=VALUES(value), expires_at=VALUES(expires_at);"

func getDB() *sql.DB {
	var ctx = context.Background()
	ctx = log.LoggerNewContext(ctx)

	Database, err := db.DbFromConfig(ctx)
	for err != nil {
		//logError(ctx, "Error: "+err.Error())
		time.Sleep(time.Duration(5) * time.Second)
		Database, err = db.DbFromConfig(ctx)
	}

	err = Database.Ping()
	for err != nil {
		time.Sleep(time.Duration(5) * time.Second)
		err = Database.Ping()
	}

	return Database
}

func (tb *DbTokenBackend) TokenInfoForToken(token string) (*TokenInfo, time.Time) {
	expires := timeToExpired(time.Now())
	data := []byte{}
	expiresAt := float64(0)
	row := tb.Db.QueryRow(
		"SELECT value, expires_at FROM chi_cache WHERE `key` = ? AND expires_at >= ?",
		tokenKey(tb, token),
		expires,
	)

	if err := row.Scan(&data, &expiresAt); err != nil {
		return nil, time.Unix(0, 0)
	}

	ti := TokenInfo{}
	err := json.Unmarshal([]byte(data), &ti)
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
	_, err = tb.Db.Exec(
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
	row := tb.Db.QueryRow(
		"SELECT COUNT(*) FROM chi_cache WHERE `key` = ? AND expires_at >= ?",
		tokenKey(tb, token),
		expired,
	)

	if err := row.Scan(&count); err != nil {
		return false
	}

	return count == 1
}

func (tb *DbTokenBackend) TouchTokenInfo(token string) {
	expired := timeToExpired(time.Now().Add(tb.inActivityTimeout))
	_, _ = tb.Db.Exec(
		"UPDATE chi_cache WHERE `key` = ? SET expires_at = ?",
		tokenKey(tb, token),
		expired,
	)
}

var _ TokenBackend = (*DbTokenBackend)(nil)

func (tb *DbTokenBackend) AdminActionsForToken(token string) map[string]bool {
	return AdminActionsForToken(tb, token)
}
