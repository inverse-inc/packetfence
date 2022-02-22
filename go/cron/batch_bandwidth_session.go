package maint

import (
	"database/sql"
	"time"
)

const bandwidthSessionSQL = `
BEGIN NOT ATOMIC
    DECLARE batch INT DEFAULT ?;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    SET @start_date = ?, @node_id = ?,  @unique_session_id = ?;
    SET @window = DATE_SUB(?, INTERVAL ? SECOND);
    SET @count = 0;

    START TRANSACTION;
    SELECT
        last_updated,
        node_id,
        unique_session_id
        INTO @next_start_date, @next_node_id, @next_unique_session_id
    FROM (
        SELECT
            last_updated,
            node_id,
            unique_session_id,
            ROW_NUMBER() OVER ( ORDER BY last_updated, node_id, unique_session_id) as row_number
        FROM (
            SELECT
                last_updated,
                node_id,
                unique_session_id
            FROM bandwidth_accounting as ba1
            WHERE (last_updated, node_id, unique_session_id) > (@start_date, @node_id, @unique_session_id) AND last_updated < @window
            ORDER BY last_updated, node_id, unique_session_id
            LIMIT batch
        ) AS x
    ) as y
    order by row_number DESC
    LIMIT 1;

    UPDATE bandwidth_accounting INNER JOIN (
    SELECT DISTINCT node_id, unique_session_id FROM (
        SELECT node_id, unique_session_id FROM (
            SELECT
                node_id,
                unique_session_id
            FROM bandwidth_accounting as ba1
            WHERE (last_updated, node_id, unique_session_id) > (@start_date, @node_id, @unique_session_id) AND last_updated < @window
            ORDER BY last_updated, node_id, unique_session_id
            LIMIT batch
        ) AS possible_old_sessions
        WHERE NOT EXISTS ( SELECT 1 FROM bandwidth_accounting ba2 WHERE ba2.last_updated >= @window AND (possible_old_sessions.node_id, possible_old_sessions.unique_session_id) = (ba2.node_id, ba2.unique_session_id) )
    ) as a ) AS old_sessions USING (node_id, unique_session_id)
    SET last_updated = '0000-00-00 00:00:00';
    SET @count = ROW_COUNT();
    COMMIT;

    SELECT @count, @next_start_date, @next_node_id, @next_unique_session_id;
END;
`

type bandwithSessionBatchCursor struct {
	batch      int
	last_date  sql.NullString
	nodeid     sql.NullInt64
	session_id sql.NullInt64
	now        time.Time
	window     int
}

func (b *bandwithSessionBatchCursor) StmtArgs() []interface{} {
	return []interface{}{
		b.batch,
		b.last_date,
		b.nodeid,
		b.session_id,
		b.now,
		b.window,
	}
}

func (b *bandwithSessionBatchCursor) Scan(row *sql.Row) (int64, error) {
	count := int64(-1)
	err := row.Scan(
		&count,
		&b.last_date,
		&b.nodeid,
		&b.session_id,
	)

	return count, err
}

func newBandwithSessionBatchCursor(batch, window int) *bandwithSessionBatchCursor {
	return &bandwithSessionBatchCursor{
		batch:      batch,
		last_date:  sql.NullString{String: "0000-01-01 00:00:00", Valid: true},
		nodeid:     sql.NullInt64{Int64: 0, Valid: true},
		session_id: sql.NullInt64{Int64: 0, Valid: true},
		now:        time.Now(),
		window:     window,
	}
}
