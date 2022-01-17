package maint

import (
    "fmt"
	"context"
	"database/sql"
	"github.com/inverse-inc/go-utils/log"
	"time"
)

type BandwidthMaintenanceSession struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
}

func NewBandwidthMaintenanceSession(config map[string]interface{}) JobSetupConfig {
	return &BandwidthMaintenanceSession{
		Task:    SetupTask(config),
		Batch:   int(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		Window:  int(config["window"].(float64)),
	}
}

const bandwidthsessionSql = `
BEGIN NOT ATOMIC
    SET @window = DATE_SUB(?, INTERVAL ? SECOND), @start_date = ?, @timedout = 0;
    CREATE OR REPLACE TABLE possible_old_sessions ENGINE=MEMORY
           SELECT DISTINCT node_id, unique_session_id
           FROM bandwidth_accounting as ba1
           WHERE last_updated BETWEEN @start_date AND @window
           ORDER BY last_updated
           LIMIT ?;
    SELECT MAX(last_updated) INTO @next_start_date FROM (SELECT MIN(last_updated) as last_updated FROM bandwidth_accounting AS ba INNER JOIN possible_old_sessions USING(node_id, unique_session_id) GROUP BY ba.node_id, ba.unique_session_id ) as x;
    UPDATE bandwidth_accounting INNER JOIN (
        SELECT ba.node_id, ba.unique_session_id
        FROM bandwidth_accounting as ba INNER JOIN possible_old_sessions USING(node_id, unique_session_id)
        GROUP BY ba.node_id, ba.unique_session_id
        HAVING MAX(ba.last_updated) BETWEEN @start_date AND @window
    ) old_sessions USING (node_id, unique_session_id)
    SET last_updated = '0000-00-00 00:00:00';
    SELECT @next_start_date as next_date, ROW_COUNT();
END;
`

func (m *BandwidthMaintenanceSession) Run() {
	ctx := context.Background()
	db, err := getDb()
	if err != nil {
		log.LogError(ctx, err.Error())
		return
	}
	stmt, err := db.Prepare(bandwidthsessionSql)
	if err != nil {
		log.LogError(ctx, err.Error())
		return
	}

	count, err := m.doCleanup(ctx, stmt, m.Timeout, time.Now(), m.Window, m.Batch)
	if err != nil {
		log.LogError(ctx, err.Error())
	}

	if count > -1 {
		log.LogInfo(context.Background(), fmt.Sprintf("%s cleaned items %d", m.Name(), count))
	}
}

func (m *BandwidthMaintenanceSession) doCleanup(ctx context.Context, stmt *sql.Stmt, time_limit time.Duration, now time.Time, window int, batch int) (int64, error) {
	begin_date := "0001-01-01 00:00:00"
	rows_affected := int64(0)
	var err error
	for {
		count := int64(0)
		err = stmt.QueryRowContext(ctx, now, window, begin_date, batch).Scan(&begin_date, &count)
		if err != nil {
			break
		}

		rows_affected += count
		if time.Now().Sub(now) > time_limit {
			break
		}
	}

	return rows_affected, err
}
