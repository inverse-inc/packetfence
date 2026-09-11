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
	// Per switch id: the instant before which the DB must not be touched again.
	switchObservabilityNextAllowed = NewShardedCache[time.Time](16)
)

// MarkSwitchAsSeen upserts the switch_observability table setting visibility_timestamp to NOW().
// It uses an in-memory cache to skip the DB update if the switch was already updated within the last minute.
func MarkSwitchAsSeen(db *sql.DB, switchID string) error {
	// Nothing to record for an empty ID (e.g. a radius_nas row with an empty
	// nasname). Returning an error here would bypass the cache and the error
	// backoff below and be logged on every single accounting request.
	if switchID == "" {
		return nil
	}

	if len(switchID) > 255 {
		return fmt.Errorf("%s: is too large to be a switch ID", switchID)
	}

	now := time.Now()
	shard := switchObservabilityNextAllowed.Shard(switchID)
	shard.Lock()
	if next, ok := shard.Get(switchID); ok && now.Before(next) {
		shard.Unlock()
		return nil
	}
	shard.Unlock()

	// Plain upsert, kept byte-for-byte identical to $sql_mark_as_seen in
	// pf::Switch (lib/pf/Switch.pm): both processes write this table and must
	// agree on the statement. The previous
	// INSERT ... WITH cte ... SELECT ... ON DUPLICATE KEY UPDATE ... VALUES()
	// form was rejected with error 1064 by MySQL. RowsAffected: 1 = inserted,
	// 2 = refreshed, 0 = row exists and is still fresh (left untouched).
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
		// get hit (and logged) again on every single flow batch / accounting
		// request. Never shorten a longer window set by a concurrent caller
		// whose upsert succeeded.
		setNextAllowed(shard, switchID, now.Add(switchObservabilityErrorBackoff), false)
		return err
	}

	rows, err := results.RowsAffected()
	if err != nil {
		return err
	}

	next := now.Add(switchObservabilityCacheTTL)
	if rows == 0 {
		// Another process refreshed the row recently; re-check halfway through
		// the TTL so this one does not fall a full period behind.
		next = now.Add(switchObservabilityCacheTTL / 2)
	}
	setNextAllowed(shard, switchID, next, true)
	return nil
}

// setNextAllowed stores the next instant at which switchID may be upserted again.
// With force=false the stored value is only moved later, never earlier.
func setNextAllowed(shard *ShardedCacheShard[time.Time], switchID string, next time.Time, force bool) {
	shard.Lock()
	defer shard.Unlock()
	if !force {
		if existing, ok := shard.Get(switchID); ok && existing.After(next) {
			return
		}
	}
	shard.Set(switchID, next)
}
