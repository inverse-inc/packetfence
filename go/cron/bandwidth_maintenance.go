package maint

import (
	"context"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"time"
)

const bandwidthMaintenanceSessionCleanupSQL = `
SET STATEMENT max_statement_time=5 FOR BEGIN NOT ATOMIC
SET @window = DATE_SUB(?, INTERVAL ? SECOND);
UPDATE bandwidth_accounting INNER JOIN (
    SELECT DISTINCT node_id, unique_session_id
    FROM bandwidth_accounting as ba1
    WHERE last_updated BETWEEN '0001-01-01 00:00:00' AND @window AND NOT EXISTS ( SELECT 1 FROM bandwidth_accounting ba2 WHERE ba2.last_updated > @window AND (ba1.node_id, ba1.unique_session_id) = (ba2.node_id, ba2.unique_session_id) )
    ORDER BY last_updated
LIMIT ?) AS old_sessions USING (node_id, unique_session_id)
SET last_updated = '0000-00-00 00:00:00';
END;
`

type BandwidthMaintenance struct {
	Task
	Window         int
	Batch          int
	Timeout        time.Duration
	HistoryWindow  int
	HistoryBatch   int
	HistoryTimeout time.Duration
	SessionWindow  int
	SessionBatch   int
	SessionTimeout time.Duration
	ClientApi      *jsonrpc2.Client
}

func NewBandwidthMaintenance(config map[string]interface{}) JobSetupConfig {
	return &BandwidthMaintenance{
		Task:           SetupTask(config),
		Batch:          int(config["batch"].(float64)),
		Timeout:        time.Duration((config["timeout"].(float64))) * time.Second,
		Window:         int(config["window"].(float64)),
		HistoryBatch:   int(config["history_batch"].(float64)),
		HistoryTimeout: time.Duration((config["history_timeout"].(float64))) * time.Second,
		HistoryWindow:  int(config["history_window"].(float64)),
		SessionBatch:   int(config["session_batch"].(float64)),
		SessionTimeout: time.Duration((config["session_timeout"].(float64))) * time.Second,
		SessionWindow:  int(config["session_window"].(float64)),
		ClientApi:      jsonrpc2.NewClientFromConfig(context.Background()),
	}
}

func (j *BandwidthMaintenance) Run() {
	ctx := context.Background()
	j.BandwidthMaintenanceSessionCleanup(ctx)
	j.ProcessBandwidthAccountingNetflow(ctx)
	j.TriggerBandwidth(ctx)
	j.BandwidthAccountingRadiusToHistory(ctx)
	//j.BandwidthAggregation(ctx, "hourly", "DATE_SUB(NOW(), INTERVAL ? HOUR)", 2)
	j.BandwidthAggregation(ctx, "daily", "DATE_SUB(NOW(), INTERVAL ? DAY)", 2)
	j.BandwidthAggregation(ctx, "monthly", "DATE_SUB(NOW(), INTERVAL ? MONTH)", 1)
	j.BandwidthHistoryAggregation(ctx, "daily", "SUBDATE(NOW(), INTERVAL ? DAY)", 1)
	j.BandwidthHistoryAggregation(ctx, "monthly", "SUBDATE(NOW(), INTERVAL ? MONTH)", 1)
	j.BandwidthAccountingHistoryCleanup(ctx)
}

func (j *BandwidthMaintenance) BandwidthMaintenanceSessionCleanup(ctx context.Context) {
	count, _ := BatchSql(
		ctx,
		j.SessionTimeout,
		bandwidthMaintenanceSessionCleanupSQL,
		time.Now(),
		j.SessionWindow,
		j.SessionBatch,
	)

	if count > -1 {
		log.LogInfo(context.Background(), fmt.Sprintf("%s cleaned items %d", "bandwidth_maintenance_session", count))
	}
}

func (j *BandwidthMaintenance) ProcessBandwidthAccountingNetflow(ctx context.Context) {
	BatchSqlCount(
		ctx,
		"process_bandwidth_accounting_netflow",
		j.Timeout,
		"CALL process_bandwidth_accounting_netflow(SUBDATE(NOW(), INTERVAL ? SECOND) ,?);",
		300,
		j.Batch,
	)

}

func (j *BandwidthMaintenance) TriggerBandwidth(ctx context.Context) {
	j.ClientApi.Call(ctx, "bandwidth_trigger", map[string]interface{}{}, 1)
}

func (j *BandwidthMaintenance) BandwidthAggregation(ctx context.Context, rounding string, date_sql string, interval int) {
	sql := "CALL bandwidth_aggregation(?, " + date_sql + ", ?)"
	BatchSqlCount(
		ctx,
		"bandwidth_aggregation-"+rounding,
		j.Timeout,
		sql,
		rounding,
		interval,
		j.Batch,
	)
}

const BandwidthAccountingRadiusToHistoryWindow = 5 * 60;

func (j *BandwidthMaintenance) BandwidthAccountingRadiusToHistory(ctx context.Context) {
	sql := "CALL bandwidth_accounting_radius_to_history(DATE_SUB(?, INTERVAL ? SECOND), ?);"
	BatchSqlCount(
		ctx,
		"bandwidth_accounting_radius_to_history",
		j.Timeout,
		sql,
		time.Now(),
		BandwidthAccountingRadiusToHistoryWindow,
		j.Batch,
	)
}

func (j *BandwidthMaintenance) BandwidthHistoryAggregation(ctx context.Context, rounding string, date_sql string, interval int) {
	sql := "CALL bandwidth_aggregation_history(?, " + date_sql + ", ?)"
	BatchSqlCount(
		ctx,
		"bandwidth_aggregation_history-"+rounding,
		j.Timeout,
		sql,
		rounding,
		interval,
		j.Batch,
	)
}

func (j *BandwidthMaintenance) BandwidthAccountingHistoryCleanup(ctx context.Context) {
	BatchSql(
		ctx,
		j.HistoryTimeout,
		"DELETE from bandwidth_accounting_history WHERE time_bucket < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?",
		time.Now(),
		j.HistoryWindow,
		j.HistoryBatch,
	)
}
