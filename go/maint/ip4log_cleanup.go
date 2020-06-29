package maint

import (
	"context"
	"database/sql"
	"fmt"
	"time"
)

type Ip4logCleanup struct {
	Task
	Window        int
	Batch         int
	Timeout       time.Duration
	Rotate        string
	RotateWindow  int
	RotateBatch   int
	RotateTimeout time.Duration
}

func NewIp4logCleanup(config map[string]interface{}) JobSetupConfig {
	return &Ip4logCleanup{
		Task:          SetupTask(config),
		Batch:         int(config["batch"].(float64)),
		Timeout:       time.Duration((config["timeout"].(float64))) * time.Second,
		Window:        int(config["window"].(float64)),
		Rotate:        config["rotate"].(string),
		RotateBatch:   int(config["rotate_batch"].(float64)),
		RotateTimeout: time.Duration((config["rotate_timeout"].(float64))) * time.Second,
		RotateWindow:  int(config["rotate_window"].(float64)),
	}
}

func (j *Ip4logCleanup) Run() {
	ctx := context.Background()
	if j.Rotate == "enabled" {
		j.DoRotate(ctx)
		BatchSql(
			ctx,
			j.Timeout,
			"DELETE FROM ip4log_archive WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?",
			time.Now(),
			j.Window,
			j.Batch,
		)
	} else {
		BatchSql(
			ctx,
			j.Timeout,
			"DELETE FROM ip4log_history WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?",
			time.Now(),
			j.Window,
			j.Batch,
		)
	}
}

func (j *Ip4logCleanup) DoRotate(ctx context.Context) {
	db, err := getDb()
	if err != nil {
		return
	}

	start := time.Now()
	rows_affected := int64(0)

	for {
		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			return
		}

		sql := `
            INSERT INTO ip4log_archive (tenant_id, mac, ip, start_time, end_time) 
              SELECT tenant_id, mac, ip, start_time, end_time FROM ip4log_history 
              WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ? ORDER BY end_time
        `
		results, err := tx.Exec(sql, start, j.RotateWindow, j.RotateBatch)
		if err != nil {
			rollBackOnErr(ctx, tx, err)
			break
		}

		rows_inserted, err := results.RowsAffected()
		if err != nil {
			rollBackOnErr(ctx, tx, err)
			break
		}

		if rows_inserted <= 0 {
			tx.Commit()
			break
		}

		sql = `
            DELETE FROM ip4log_history 
              WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ? ORDER BY end_time
        `
		results, err = tx.Exec(sql, start, j.RotateWindow, j.RotateBatch)
		if err != nil {
			rollBackOnErr(ctx, tx, err)
			break
		}

		rows_deleted, err := results.RowsAffected()
		if err != nil {
			rollBackOnErr(ctx, tx, err)
			break
		}

		if err := tx.Commit(); err != nil {
			logError(ctx, "Database error: "+err.Error())
			break
		}

		if rows_deleted != rows_inserted {
			logWarn(ctx, fmt.Sprintf("When rotating ip4log the number of rows deleted (%d) does not match the number of row inserted (%d)", rows_deleted, rows_inserted))
		}

		rows_affected += rows_inserted
		if time.Now().Sub(start) > j.Timeout {
			break
		}

	}
}

func rollBackOnErr(ctx context.Context, tx *sql.Tx, err error) {
	if rollbackErr := tx.Rollback(); rollbackErr != nil {
		logError(ctx, "Database error: "+rollbackErr.Error())
	}
	logError(ctx, "Database error: "+err.Error())
}
