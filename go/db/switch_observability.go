package db

import (
	"database/sql"
	"time"
)

var (
	switchObservabilityCacheTTLInMinutes = 1
	switchObservabilityCacheTTL          = time.Duration(switchObservabilityCacheTTLInMinutes) * time.Minute
	switchObservabilityCache             = NewShardedCache[time.Time](16)
)

// MarkSwitchAsSeen upserts the switch_observability table setting visibility_timestamp to NOW().
// It uses an in-memory cache to skip the DB update if the switch was already updated within the last minute.
func MarkSwitchAsSeen(db *sql.DB, switchID string) error {
	shard := switchObservabilityCache.Shard(switchID)
	shard.Lock()
	defer shard.Unlock()
	if lastSeen, ok := shard.Get(switchID); ok && time.Since(lastSeen) < switchObservabilityCacheTTL {
		return nil
	}

	results, err := db.Exec(
		`INSERT INTO switch_observability (switch_id, visibility_timestamp)
		WITH cte AS (SELECT ? as switch_id)
		SELECT switch_id, NOW() FROM cte LEFT JOIN switch_observability USING (switch_id) WHERE visibility_timestamp IS NULL OR DATE_SUB(NOW(), INTERVAL ? MINUTE) > visibility_timestamp
		ON DUPLICATE KEY UPDATE visibility_timestamp = VALUES(visibility_timestamp)`,
		switchID,
		switchObservabilityCacheTTLInMinutes,
	)

	if err != nil {
		return err
	}

	rows, err := results.RowsAffected()
	if err == nil && rows > 0 {
		shard.Set(switchID, time.Now())
		return nil
	}

	return err
}
