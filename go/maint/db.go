package maint

import (
	"context"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/tryableonce"
)

var dbh *sql.DB
var dbhOnce tryableonce.TryableOnce

func getDb() (*sql.DB, error) {
	err := dbhOnce.Do(
		func() error {
			var ctx = context.Background()
			_dbh, err := db.DbFromConfig(ctx)
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
