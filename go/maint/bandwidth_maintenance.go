package maint

import (
	"context"
	"time"
)

type BandwidthMaintenance struct {
	Task
	Window         int
	Batch          int
	Timeout        time.Duration
	HistoryWindow  int
	HistoryBatch   int
	HistoryTimeout time.Duration
}

func NewBandwidthMaintenance(config map[string]interface{}) JobSetupConfig {
	return &BandwidthMaintenance{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Batch:          int(config["batch"].(float64)),
		Timeout:        time.Duration((config["timeout"].(float64))) * time.Second,
		Window:         int(config["window"].(float64)),
		HistoryBatch:   int(config["history_batch"].(float64)),
		HistoryTimeout: time.Duration((config["history_timeout"].(float64))) * time.Second,
		HistoryWindow:  int(config["history_window"].(float64)),
	}
}

func (j *BandwidthMaintenance) Run() {
	ctx := context.Background()
	j.ProcessBandwidthAccountingNetflow(ctx)
	j.TriggerBandwidth()
	j.BandwidthAggregation(ctx, "hourly", "DATE_SUB(NOW(), INTERVAL ? HOUR)", 2)
	j.BandwidthAggregation(ctx, "daily", "DATE_SUB(NOW(), INTERVAL ? DAY)", 2)
	j.BandwidthAggregation(ctx, "monthly", "DATE_SUB(NOW(), INTERVAL ? MONTHLY)", 1)
	j.BandwidthAccountingRadiusToHistory(ctx)
	j.BandwidthHistoryAggregation(ctx, "daily", "SUBDATE(NOW(), INTERVAL ? DAY)", 1)
	j.BandwidthHistoryAggregation(ctx, "monthly", "SUBDATE(NOW(), INTERVAL ? MONTH)", 1)
	j.BandwidthAccountingHistoryCleanup(ctx)
}

func (j *BandwidthMaintenance) ProcessBandwidthAccountingNetflow(ctx context.Context) {
	batchSqlCount(
		ctx,
		j.Timeout,
		"CALL process_bandwidth_accounting_netflow(SUBDATE(NOW(), INTERVAL ? SECOND) ,?);",
		300,
		j.Batch,
	)
}

func batchSqlCount(ctx context.Context, timeout time.Duration, sql string, args ...interface{}) {
	db, err := getDb()
	if err != nil {
		logError(ctx, err.Error())
		return
	}

	stmt, err := db.Prepare(sql)
	if err != nil {
		logError(ctx, err.Error())
		return
	}

	defer stmt.Close()
	BatchStmtQueryWithCount(ctx, stmt, timeout, args...)
}

func batchSql(ctx context.Context, timeout time.Duration, sql string, args ...interface{}) {
	db, err := getDb()
	if err != nil {
		logError(ctx, err.Error())
		return
	}

	stmt, err := db.Prepare(sql)
	if err != nil {
		logError(ctx, err.Error())
		return
	}

	defer stmt.Close()
	BatchStmt(ctx, stmt, timeout, args...)
}

func (j *BandwidthMaintenance) TriggerBandwidth() {
}

func (j *BandwidthMaintenance) BandwidthAggregation(ctx context.Context, rounding string, date_sql string, interval int) {
	sql := "CALL bandwidth_aggregation(?, " + date_sql + ", ?)"
	batchSqlCount(ctx, j.Timeout, sql, rounding, interval, j.Batch)
}

func (j *BandwidthMaintenance) BandwidthAccountingRadiusToHistory(ctx context.Context) {
	sql := "CALL bandwidth_accounting_radius_to_history(DATE_SUB(NOW(), INTERVAL ? SECOND), ?);"
	batchSqlCount(ctx, j.Timeout, sql, j.Window, j.Batch)
}

func (j *BandwidthMaintenance) BandwidthHistoryAggregation(ctx context.Context, rounding string, date_sql string, interval int) {
	sql := "CALL bandwidth_aggregation_history(?, " + date_sql + ", ?)"
	batchSqlCount(ctx, j.Timeout, sql, rounding, interval, j.Batch)
}

func (j *BandwidthMaintenance) BandwidthAccountingHistoryCleanup(ctx context.Context) {
	batchSql(
		ctx,
		j.HistoryTimeout,
		"DELETE from bandwidth_accounting_history WHERE time_bucket < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?",
		time.Now(),
		j.HistoryWindow,
		j.HistoryBatch,
	)
}
