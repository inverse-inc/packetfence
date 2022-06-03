package maint

import (
	"context"
	"fmt"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
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
		ClientApi:      jsonrpc2.NewClientFromConfig(context.Background()),
	}
}

func (j *BandwidthMaintenance) Run() {
	ctx := context.Background()
	j.ProcessBandwidthAccountingNetflow(ctx)
	j.TriggerBandwidth(ctx)
	j.BandwidthAggregation(ctx, "ROUND_TO_HOUR", "HOUR", 1)
	j.BandwidthAggregation(ctx, "DATE", "DAY", 1)
	j.BandwidthAggregation(ctx, "ROUND_TO_MONTH", "MONTH", 1)
	j.BandwidthAccountingRadiusToHistory(ctx)
	j.BandwidthHistoryAggregation(ctx, "daily", "SUBDATE(NOW(), INTERVAL ? DAY)", 1)
	j.BandwidthHistoryAggregation(ctx, "monthly", "SUBDATE(NOW(), INTERVAL ? MONTH)", 1)
	j.BandwidthAccountingHistoryCleanup(ctx)
}

func (j *BandwidthMaintenance) ProcessBandwidthAccountingNetflow(ctx context.Context) {
	BatchSqlCount(
		ctx,
		j.Timeout,
		"CALL process_bandwidth_accounting_netflow(SUBDATE(NOW(), INTERVAL ? SECOND) ,?);",
		300,
		j.Batch,
	)
}

func (j *BandwidthMaintenance) TriggerBandwidth(ctx context.Context) {
	j.ClientApi.Call(ctx, "bandwidth_trigger", map[string]interface{}{}, 1)
}

func (j *BandwidthMaintenance) BandwidthAccountingRadiusToHistory(ctx context.Context) {
	sql := "CALL bandwidth_accounting_radius_to_history(DATE_SUB(NOW(), INTERVAL ? SECOND), ?);"
	BatchSqlCount(ctx, j.Timeout, sql, j.Window, j.Batch)
}

func (j *BandwidthMaintenance) BandwidthHistoryAggregation(ctx context.Context, rounding string, date_sql string, interval int) {
	sql := "CALL bandwidth_aggregation_history(?, " + date_sql + ", ?)"
	BatchSqlCount(ctx, j.Timeout, sql, rounding, interval, j.Batch)
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

func (j *BandwidthMaintenance) BandwidthAggregation(ctx context.Context, rounding_func, unit string, interval int) {
	sql := fmt.Sprintf(`
BEGIN NOT ATOMIC
    DECLARE EXIT HANDLER
    FOR SQLEXCEPTION
    BEGIN
    ROLLBACK;
    RESIGNAL;
    END;
    SET @count = 0;
    SET @end_bucket = DATE_SUB(?, INTERVAL ? %s);
    START TRANSACTION;
    INSERT INTO bandwidth_accounting
    (node_id, unique_session_id, tenant_id, mac, time_bucket, in_bytes, out_bytes, last_updated, source_type)
     SELECT
         node_id,
         unique_session_id,
         tenant_id,
         mac,
         new_time_bucket,
         sum(in_bytes) AS in_bytes,
         sum(out_bytes) AS out_bytes,
         MAX(last_updated),
         "radius"
        FROM (
            SELECT
                node_id,
                unique_session_id,
                tenant_id,
                mac,
                %s(time_bucket) as new_time_bucket,
                in_bytes,
                out_bytes,
                last_updated FROM bandwidth_accounting
            WHERE time_bucket <=  @end_bucket AND source_type = "radius" AND time_bucket != %s(time_bucket)
            ORDER BY node_id, unique_session_id, time_bucket
            LIMIT ? FOR UPDATE
        ) AS to_delete_bandwidth_aggregation
        GROUP BY node_id, unique_session_id, new_time_bucket
        ON DUPLICATE KEY UPDATE
            in_bytes = in_bytes + VALUES(in_bytes),
            out_bytes = out_bytes + VALUES(out_bytes),
            last_updated = GREATEST(last_updated, VALUES(last_updated))
        ;

    DELETE bandwidth_accounting
        FROM bandwidth_accounting RIGHT JOIN (
            SELECT
                node_id,
                unique_session_id,
                time_bucket
            FROM bandwidth_accounting
            WHERE time_bucket <=  @end_bucket AND source_type = "radius" AND time_bucket != %s(time_bucket)
            ORDER BY node_id, unique_session_id, time_bucket
            LIMIT ? FOR UPDATE
        ) AS to_delete_bandwidth_aggregation USING(node_id, unique_session_id, time_bucket);
    SET @count = ROW_COUNT();
    COMMIT;
    SELECT @count;
END;
`,
		unit,
		rounding_func,
		rounding_func,
		rounding_func,
	)
	BatchSqlCount(
		ctx,
		j.Timeout,
		sql,
		time.Now(),
		interval,
		j.Batch,
		j.Batch,
	)
}
