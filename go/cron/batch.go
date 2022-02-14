package maint

import (
	"context"
	"database/sql"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

func BatchStmt(ctx context.Context, time_limit time.Duration, stmt *sql.Stmt, args ...interface{}) (int64, error) {
	start := time.Now()
	rows_affected := int64(0)
	for {
		results, err := stmt.Exec(args...)
		if err != nil {
			log.LogError(ctx, "Database error: "+err.Error())
			return rows_affected, err
		}

		rows, err := results.RowsAffected()
		if err != nil {
			log.LogError(ctx, "Database error: "+err.Error())
			return rows_affected, err
		}

		if rows <= 0 {
			break
		}

		rows_affected += rows
		if time.Now().Sub(start) > time_limit {
			break
		}
	}

	return rows_affected, nil
}

func BatchStmtQueryWithCount(ctx context.Context, name string, time_limit time.Duration, stmt *sql.Stmt, args ...interface{}) int64 {
	start := time.Now()
	rows_affected := int64(0)
	i := 0
	for {
		i++
		var count int64
		err := stmt.QueryRow(args...).Scan(&count)
		if err != nil {
			log.LogError(ctx, fmt.Sprintf("%d) Database error (%s): %s", i, name, err.Error()))
			time.Sleep(10 * time.Millisecond)
		} else {

			if count == 0 {
				break
			}

			if count < 0 {
				log.LogWarn(ctx, fmt.Sprintf("%d) Retrying query for %s", i, name))
				time.Sleep(10 * time.Millisecond)
			} else {
				rows_affected += count
			}
		}

		if time.Now().Sub(start) > time_limit {
			break
		}
	}

	if rows_affected > -1 {
		log.LogInfo(ctx, fmt.Sprintf("%s called times %d and handled %d items", name, i, rows_affected))
	}

	return rows_affected
}

func BatchSql(ctx context.Context, timeout time.Duration, sql string, args ...interface{}) (int64, error) {
	db, err := getDb()
	if err != nil {
		log.LogError(ctx, err.Error())
		return -1, err
	}

	stmt, err := db.Prepare(sql)
	if err != nil {
		log.LogError(ctx, err.Error())
		return -1, err
	}

	defer stmt.Close()
	return BatchStmt(ctx, timeout, stmt, args...)
}

func BatchSingleSql(ctx context.Context, sql string, args ...interface{}) error {
	db, err := getLocalDb()
	if err != nil {
		log.LogError(ctx, err.Error())
		return err
	}

	sql = strings.Replace(sql, "?", strconv.Itoa(args[0].(int)), -1)
	_, err = db.ExecContext(ctx, sql)
	if err != nil {
		log.LogError(ctx, err.Error())
		return err
	}
	return nil
}

func BatchSqlCount(ctx context.Context, name string, timeout time.Duration, sql string, args ...interface{}) {
	db, err := getDb()
	if err != nil {
		log.LogError(ctx, err.Error())
		return
	}

	stmt, err := db.Prepare(sql)
	if err != nil {
		log.LogError(ctx, err.Error())
		return
	}

	defer stmt.Close()
	BatchStmtQueryWithCount(ctx, name, timeout, stmt, args...)
}
