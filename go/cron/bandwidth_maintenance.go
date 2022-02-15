package maint

import (
	"context"
	"fmt"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
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
	j.BandwidthAggregation(ctx, "ROUND_TO_HOUR", "HOUR", 1)
	j.BandwidthAggregation(ctx, "DATE", "DAY", 1)
	j.BandwidthAggregation(ctx, "ROUND_TO_MONTH", "MONTH", 1)
	j.BandwidthHistoryAggregation(ctx, "DATE", "DAY", 1)
	j.BandwidthHistoryAggregation(ctx, "ROUND_TO_MONTH", "MONTH", 1)
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
	sql := `
BEGIN NOT ATOMIC
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    SET @count = 0;
    SET @end_bucket = DATE_SUB(?, INTERVAL ? SECOND);
    START TRANSACTION;
    UPDATE
     node INNER JOIN
        (
            SELECT
                tenant_id, mac, SUM(total_bytes) AS total_bytes
                FROM (
                    SELECT node_id, tenant_id, mac, total_bytes FROM bandwidth_accounting WHERE source_type = "net_flow" AND time_bucket < @end_bucket ORDER BY node_id, unique_session_id, time_bucket LIMIT ? FOR UPDATE
                ) AS to_process_bandwidth_accounting_netflow GROUP BY node_id
        ) AS summarization
        SET node.bandwidth_balance = GREATEST(node.bandwidth_balance - total_bytes, 0)
        WHERE node.bandwidth_balance IS NOT NULL;

    INSERT INTO bandwidth_accounting_history
    (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
     SELECT
         node_id,
         tenant_id,
         mac,
         new_time_bucket,
         sum(in_bytes) AS in_bytes,
         sum(out_bytes) AS out_bytes
        FROM (
            SELECT node_id, tenant_id, mac, ROUND_TO_HOUR(time_bucket) as new_time_bucket, in_bytes, out_bytes FROM bandwidth_accounting WHERE source_type = "net_flow" AND time_bucket < @end_bucket ORDER BY node_id, unique_session_id, time_bucket LIMIT ? FOR UPDATE
        ) AS to_process_bandwidth_accounting_netflow
        GROUP BY node_id, new_time_bucket
        ON DUPLICATE KEY UPDATE
            in_bytes = in_bytes + VALUES(in_bytes),
            out_bytes = out_bytes + VALUES(out_bytes)
        ;

    DELETE bandwidth_accounting
    FROM bandwidth_accounting RIGHT JOIN (
            SELECT node_id, time_bucket, unique_session_id FROM bandwidth_accounting WHERE source_type = "net_flow" AND time_bucket < @end_bucket ORDER BY node_id, unique_session_id, time_bucket LIMIT ? FOR UPDATE
    ) as to_process_bandwidth_accounting_netflow USING (node_id, time_bucket, unique_session_id);
    SET @count = ROW_COUNT();
    COMMIT;
    SELECT @count;
END;
`
	BatchSqlCount(
		ctx,
		"process_bandwidth_accounting_netflow",
		j.Timeout,
		sql,
		time.Now(),
		300,
		j.Batch,
		j.Batch,
		j.Batch,
	)

}

func (j *BandwidthMaintenance) TriggerBandwidth(ctx context.Context) {
	j.ClientApi.Call(ctx, "bandwidth_trigger", map[string]interface{}{}, 1)
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
		"bandwidth_aggregation-"+unit,
		j.Timeout,
		sql,
		time.Now(),
		interval,
		j.Batch,
		j.Batch,
	)
}

const BandwidthAccountingRadiusToHistoryWindow = 24 * 60 * 60

func (j *BandwidthMaintenance) BandwidthAccountingRadiusToHistory(ctx context.Context) {
	sql := `
BEGIN NOT ATOMIC
   DECLARE EXIT HANDLER
   FOR SQLEXCEPTION
   BEGIN
       ROLLBACK;
    RESIGNAL;
END;

    SET @count = 0;
    SET @end_bucket = DATE_SUB(?, INTERVAL ? SECOND);
    START TRANSACTION;
INSERT INTO bandwidth_accounting_history
    (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
     SELECT
         node_id,
         tenant_id,
         mac,
         new_time_bucket,
         sum(in_bytes) AS in_bytes,
         sum(out_bytes) AS out_bytes
        FROM (
            SELECT node_id, tenant_id, mac, ROUND_TO_HOUR(time_bucket) as new_time_bucket, in_bytes, out_bytes FROM bandwidth_accounting WHERE source_type = "radius" AND time_bucket < @end_bucket AND last_updated = "0000-00-00 00:00:00" ORDER BY node_id, unique_session_id, time_bucket LIMIT ? FOR UPDATE ) as to_delete_bandwidth_accounting_radius_to_history
        GROUP BY node_id, new_time_bucket
        HAVING SUM(in_bytes) != 0 OR sum(out_bytes) != 0
        ON DUPLICATE KEY UPDATE
            in_bytes = in_bytes + VALUES(in_bytes),
            out_bytes = out_bytes + VALUES(out_bytes)
        ;

DELETE bandwidth_accounting
            FROM bandwidth_accounting RIGHT JOIN (
                SELECT node_id, unique_session_id, mac, time_bucket FROM bandwidth_accounting WHERE source_type = "radius" AND time_bucket < @end_bucket AND last_updated = "0000-00-00 00:00:00" ORDER BY node_id, unique_session_id, time_bucket LIMIT ? FOR UPDATE
            ) AS to_delete_bandwidth_accounting_radius_to_history USING (node_id, time_bucket, unique_session_id);
        SET @count = ROW_COUNT();
     COMMIT;
    SELECT @count;
END;
`
	BatchSqlCount(
		ctx,
		"bandwidth_accounting_radius_to_history",
		j.Timeout,
		sql,
		time.Now(),
		BandwidthAccountingRadiusToHistoryWindow,
		j.Batch,
		j.Batch,
	)
}

func (j *BandwidthMaintenance) BandwidthHistoryAggregation(ctx context.Context, rounding_func, unit string, interval int) {
	sql := fmt.Sprintf(
		`
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
    INSERT INTO bandwidth_accounting_history
    (node_id, time_bucket, tenant_id, mac, in_bytes, out_bytes)
     SELECT
         node_id,
         new_time_bucket,
         tenant_id,
         mac,
         sum(in_bytes) AS in_bytes,
         sum(out_bytes) AS out_bytes
        FROM (
        SELECT node_id, %s(time_bucket) as new_time_bucket, tenant_id, mac, in_bytes, out_bytes FROM bandwidth_accounting_history WHERE time_bucket <= @end_bucket AND time_bucket != %s(time_bucket) ORDER BY node_id, time_bucket LIMIT ? FOR UPDATE ) AS to_delete_bandwidth_aggregation_history
        GROUP BY node_id, new_time_bucket
        ON DUPLICATE KEY UPDATE
            in_bytes = in_bytes + VALUES(in_bytes),
            out_bytes = out_bytes + VALUES(out_bytes)
        ;

    DELETE bandwidth_accounting_history
        FROM bandwidth_accounting_history RIGHT JOIN (SELECT node_id, time_bucket FROM bandwidth_accounting_history WHERE time_bucket <= @end_bucket AND time_bucket != %s(time_bucket) ORDER BY node_id, time_bucket LIMIT ? FOR UPDATE ) AS to_delete_bandwidth_aggregation_history USING (node_id, time_bucket);
        SET @count = ROW_COUNT();
        COMMIT;
    SELECT @count;
END;`,
		unit,
		rounding_func,
		rounding_func,
		rounding_func,
	)
	BatchSqlCount(
		ctx,
		"bandwidth_aggregation_history-"+unit,
		j.Timeout,
		sql,
		time.Now(),
		interval,
		j.Batch,
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
