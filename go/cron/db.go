package maint

import (
	"context"
	"database/sql"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/tryableonce"
)

var dbh *sql.DB
var dbhOnce tryableonce.TryableOnce

func getDb() (*sql.DB, error) {
	err := dbhOnce.Do(
		func() error {
			var ctx = context.Background()
			var successDBConnect = false
			_dbh, err := db.DbFromConfig(ctx)
			for err != nil {
				if err != nil {
					time.Sleep(time.Duration(5) * time.Second)
				}

				_dbh, err = db.DbFromConfig(ctx)
			}

			for !successDBConnect {
				err = _dbh.Ping()
				if err != nil {
					time.Sleep(time.Duration(5) * time.Second)
				} else {
					successDBConnect = true
				}
			}

			dbh = _dbh
			return nil
		},
	)

	if err != nil {
		return nil, err
	}

	return dbh, nil
}

func getLocalDb() (*sql.DB, error) {
	err := dbhOnce.Do(
		func() error {
			var ctx = context.Background()
			_dbh, err := db.DbLocalFromConfig(ctx)
			if err != nil {
				return err
			}

			dbh = _dbh
			return nil
		},
	)

	if err != nil {
		return nil, err
	}

	return dbh, nil
}

func rollBackOnErr(ctx context.Context, tx *sql.Tx, err error) {
	if rollbackErr := tx.Rollback(); rollbackErr != nil {
		log.LogError(ctx, "Database error: "+rollbackErr.Error())
	}
	log.LogError(ctx, "Database error: "+err.Error())
}
