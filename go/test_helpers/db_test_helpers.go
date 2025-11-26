package test_helpers

import (
	"context"
	"database/sql"
	"fmt"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/tryableonce"
)

var dbh *sql.DB
var dbhOnce tryableonce.TryableOnce

func GetDb() (*sql.DB, error) {
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

func RunStatements(statements []string) error {
	db, err := GetDb()
	if err != nil {
		return fmt.Errorf("Cannot connect to db error: %s", err.Error())
	}
	for _, sql := range statements {
		_, err = db.Exec(sql)
		if err != nil {
			return fmt.Errorf("Invalid SQL '%s': %s", sql, err.Error())
		}
	}
	return nil
}
