package maint

import (
	"context"
	"database/sql"
	"sync"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/tryableonce"
)

var dbh *sql.DB
var localDbh *sql.DB
var dbhOnce sync.Once
var localDbhOnce tryableonce.TryableOnce

func getDb() (*sql.DB, error) {
	dbhOnce.Do(
		func() {
			var ctx = context.Background()
			_dbh, err := db.OpenDBFromConfig(ctx)
			if err != nil {
				panic("Cannot database config: " + err.Error())
			}

			dbh = _dbh
		},
	)

	return dbh, nil
}

func getLocalDb() (*sql.DB, error) {
	err := localDbhOnce.Do(
		func() error {
			var ctx = context.Background()
			_dbh, err := db.DbLocalFromConfig(ctx)
			if err != nil {
				return err
			}

			localDbh = _dbh
			return nil
		},
	)

	if err != nil {
		return nil, err
	}

	return localDbh, nil
}

func rollBackOnErr(ctx context.Context, tx *sql.Tx, err error) {
	if rollbackErr := tx.Rollback(); rollbackErr != nil {
		log.LogError(ctx, "Database error: "+rollbackErr.Error())
	}
	log.LogError(ctx, "Database error: "+err.Error())
}
