package maint

import (
	"context"
	"database/sql"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
)

// getDb returns the shared pool for the configured database. Never Close it.
func getDb() (*sql.DB, error) {
	return db.DbFromConfig(context.Background())
}

// getLocalDb returns the shared pool for the local database socket. Never
// Close it.
func getLocalDb() (*sql.DB, error) {
	return db.DbLocalFromConfig(context.Background())
}

func rollBackOnErr(ctx context.Context, tx *sql.Tx, err error) {
	if rollbackErr := tx.Rollback(); rollbackErr != nil {
		log.LogError(ctx, "Database error: "+rollbackErr.Error())
	}
	log.LogError(ctx, "Database error: "+err.Error())
}
