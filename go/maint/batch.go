package maint

import (
	"database/sql"
	"time"
)

func BatchRemove(stmt *sql.Stmt, time_limit time.Duration, args ...interface{}) int64 {
	start := time.Now()
	rows_deleted := int64(0)
	for {
		results, err := stmt.Exec(args...)
		if err != nil {
			break
		}

		rows, err := results.RowsAffected()
		if err != nil {
			break
		}

		if rows <= 0 {
			break
		}

		rows_deleted += rows
		if time.Now().Sub(start) > time_limit {
			break
		}
	}

	return rows_deleted
}
