package db

import (
	"database/sql"
	"fmt"
	"time"
)

var (
	switchObservabilityCacheTTLInMinutes = 1
	switchObservabilityCacheTTL          = time.Duration(switchObservabilityCacheTTLInMinutes) * time.Minute
	switchObservabilityErrorBackoff      = 10 * time.Second
	switchObservabilityCache             = NewShardedCache[time.Time](16)
)

// MarkSwitchAsSeen upserts the switch_observability table setting visibility_timestamp to NOW().
// It uses an in-memory cache to skip the DB update if the switch was already updated within the last minute.
func MarkSwitchAsSeen(db *sql.DB, switchID string) error {
	if switchID == "" {
		return fmt.Errorf("empty switch ID")
	}

	if len(switchID) > 255 {
		return fmt.Errorf("%s: is too large to be a switch ID", switchID)
	}

	shard := switchObservabilityCache.Shard(switchID)
	shard.Lock()
	if lastSeen, ok := shard.Get(switchID); ok && time.Since(lastSeen) < switchObservabilityCacheTTL {
		shard.Unlock()
		return nil
	}
	shard.Unlock()

	// No CTE here on purpose: this runs against MariaDB and MySQL (5.7 has no
	// CTE support, and INSERT ... WITH ... SELECT is not portable). VALUES() in
	// ON DUPLICATE KEY UPDATE is also avoided since MySQL 8.0.20+ deprecates it.
	// A plain upsert keeps the same RowsAffected semantics: 1 = inserted,
	// 2 = updated, 0 = row exists and is still fresh (left untouched).
	results, err := db.Exec(
		`INSERT INTO switch_observability (switch_id, visibility_timestamp)
		VALUES (?, NOW())
		ON DUPLICATE KEY UPDATE visibility_timestamp = IF(
			visibility_timestamp IS NULL OR visibility_timestamp < DATE_SUB(NOW(), INTERVAL ? MINUTE),
			NOW(),
			visibility_timestamp
		)`,
		switchID,
		switchObservabilityCacheTTLInMinutes,
	)

	if err != nil {
		// Remember the failure for a short while so a broken database does not
		// get hit (and logged) again on every single flow batch / accounting request.
		shard.Lock()
		shard.Set(switchID, time.Now().Add(-1*(switchObservabilityCacheTTL-switchObservabilityErrorBackoff)))
		shard.Unlock()
		return err
	}

	rows, err := results.RowsAffected()
	if err == nil {
		now := time.Now()
		if rows == 0 {
			now = now.Add(-1 * switchObservabilityCacheTTL / 2)
		}
		shard.Lock()
		defer shard.Unlock()
		shard.Set(switchID, now)
		return nil
	}

	return err
}
