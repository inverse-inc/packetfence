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

// markSwitchAsSeenSQL is a plain upsert, kept identical to $sql_mark_as_seen in
// pf::Switch (lib/pf/Switch.pm): both processes write this table and must agree
// on the statement (TestPerlMarkAsSeenStatementMatchesGo enforces it).
//
// The previous INSERT ... WITH cte ... SELECT ... ON DUPLICATE KEY UPDATE ...
// VALUES() form is accepted by MariaDB 10.11 and MySQL 8.0/8.4 but rejected
// with error 1064 by MySQL 5.7, which has no CTE support. This form runs on all
// four (see switch_observability_integration_test.go) with the same
// RowsAffected contract the callers rely on: 1 = inserted, 2 = refreshed,
// 0 = row exists and is still fresh (left untouched). go/db never enables
// CLIENT_FOUND_ROWS and pf::db sets mysql_client_found_rows=0, so 0 really
// means untouched on both sides.
const markSwitchAsSeenSQL = `INSERT INTO switch_observability (switch_id, visibility_timestamp)
VALUES (?, NOW())
ON DUPLICATE KEY UPDATE visibility_timestamp = IF(
    visibility_timestamp IS NULL OR visibility_timestamp < DATE_SUB(NOW(), INTERVAL ? MINUTE),
    NOW(),
    visibility_timestamp
)`

// execMarkSwitchAsSeen runs the upsert and returns the number of affected rows
// (see markSwitchAsSeenSQL for their meaning).
func execMarkSwitchAsSeen(db *sql.DB, switchID string) (int64, error) {
	results, err := db.Exec(markSwitchAsSeenSQL, switchID, switchObservabilityCacheTTLInMinutes)
	if err != nil {
		return 0, err
	}
	return results.RowsAffected()
}

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

	rows, err := execMarkSwitchAsSeen(db, switchID)
	if err != nil {
		// Remember the failure for a short while so a broken database does not
		// get hit (and logged) again on every single flow batch / accounting
		// request. Never shorten a longer window set by a concurrent caller
		// whose upsert succeeded.
		setNextAllowed(shard, switchID, now.Add(switchObservabilityErrorBackoff), false)
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
