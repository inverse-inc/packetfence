package maint

import (
	"context"
	"database/sql"
	"time"
)

func BatchStmt(ctx context.Context, stmt *sql.Stmt, time_limit time.Duration, args ...interface{}) int64 {
	start := time.Now()
	rows_affected := int64(0)
	for {
		results, err := stmt.Exec(args...)
		if err != nil {
			break
		}

		rows, err := results.RowsAffected()
		if err != nil {
			logError(ctx, "Database error: "+err.Error())
			break
		}

		if rows <= 0 {
			break
		}

		rows_affected += rows
		if time.Now().Sub(start) > time_limit {
			break
		}
	}

	return rows_affected
}

func BatchStmtQueryWithCount(ctx context.Context, stmt *sql.Stmt, time_limit time.Duration, args ...interface{}) int64 {
	start := time.Now()
	rows_affected := int64(0)
	for {
		var count int64
		err := stmt.QueryRow(args...).Scan(&count)
		if err != nil {
			logError(ctx, "Database error: "+err.Error())
			break
		}

		if count <= 0 {
			break
		}

		rows_affected += count
		if time.Now().Sub(start) > time_limit {
			break
		}
	}

	return rows_affected
}
