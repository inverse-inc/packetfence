package main

import (
	"strconv"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-utils/mac"
)

// The node_current_session upsert only feeds the admin UI's online/offline
// indicator and the 24h-window cleanup job, so refreshing `updated` every few
// minutes per session carries the same information as refreshing it on every
// interim update. The window must comfortably exceed the NAS interim-update
// interval or every interim misses the cache and nothing is saved.
const sessionOnlineRefreshTtl = 10 * time.Minute

// rateLimitedNodeOnlineOffline wraps updateNodeOnlineOfflineOnline: the
// Start/Interim upsert runs at most once per sessionOnlineRefreshTtl per
// (MAC, session), while Stop always executes (it flips is_online off) and
// drops the cache entry so a same-session Start afterwards re-marks the node
// online immediately.
func (h *PfAcct) rateLimitedNodeOnlineOffline(status rfc2866.AcctStatusType, m mac.Mac, sessionID uint64) error {
	key := m.String() + "|" + strconv.FormatUint(sessionID, 10)

	if status == rfc2866.AcctStatusType_Value_Stop {
		h.SessionOnlineCache.Delete(key)
		return h.updateNodeOnlineOfflineOnline(status, m, sessionID)
	}

	if _, found := h.SessionOnlineCache.Get(key); found {
		return nil
	}

	err := h.updateNodeOnlineOfflineOnline(status, m, sessionID)
	if err == nil {
		h.SessionOnlineCache.Set(key, 1, cache.DefaultExpiration)
	}
	return err
}
