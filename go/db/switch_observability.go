package db

import (
	"database/sql"
	"sync"
	"time"
)

var (
	switchObservabilityCache   = make(map[string]time.Time)
	switchObservabilityMu      sync.Mutex
	switchObservabilityCacheTTL = 1 * time.Minute
)

// MarkSwitchAsSeen upserts the switch_observability table setting visibility_timestamp to NOW().
// It uses an in-memory cache to skip the DB update if the switch was already updated within the last minute.
func MarkSwitchAsSeen(db *sql.DB, switchID string) error {
	switchObservabilityMu.Lock()
	if lastSeen, ok := switchObservabilityCache[switchID]; ok && time.Since(lastSeen) < switchObservabilityCacheTTL {
		switchObservabilityMu.Unlock()
		return nil
	}
	switchObservabilityCache[switchID] = time.Now()
	switchObservabilityMu.Unlock()

	_, err := db.Exec(
		`INSERT INTO switch_observability (switch_id, visibility_timestamp) VALUES (?, NOW())
		 ON DUPLICATE KEY UPDATE visibility_timestamp = NOW()`,
		switchID,
	)
	if err != nil {
		// Remove from cache so it retries next time
		switchObservabilityMu.Lock()
		delete(switchObservabilityCache, switchID)
		switchObservabilityMu.Unlock()
	}
	return err
}
