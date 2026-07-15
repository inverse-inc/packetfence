package main

import (
	"strconv"
	"time"

	cache "github.com/fdurand/go-cache"
)

// nodeSession entries are normally removed when the accounting Stop arrives.
// A missed or dropped Stop (common under load) would otherwise leave the entry
// in the cache forever, leaking memory. nodeSessionExpiration bounds how long
// an idle entry survives and nodeSessionCleanupInterval drives the janitor that
// evicts expired entries. The expiration is refreshed on every access (see
// getNodeSessionFromCache), so it behaves as an idle timeout: active sessions
// never expire, abandoned ones are reclaimed.
const nodeSessionExpiration = 12 * time.Hour
const nodeSessionCleanupInterval = 15 * time.Minute

type nodeSession struct {
	timeBalance      int64
	bandwidthBalance int64
}

func formatNodeId(sessionId uint64) string {
	return strconv.FormatUint(sessionId, 36)
}

func (h *PfAcct) setNodeSessionCache(sessionId uint64, ns *nodeSession) {
	nodeId := formatNodeId(sessionId)
	h.NodeSessionCache.Set(nodeId, ns, cache.DefaultExpiration)
}

func (h *PfAcct) getNodeSessionFromCache(sessionId uint64) *nodeSession {
	nodeId := formatNodeId(sessionId)
	if i, found := h.NodeSessionCache.Get(nodeId); found {
		ns := i.(*nodeSession)
		// Refresh the idle timeout so long-lived, still-active sessions are
		// never evicted mid-session.
		h.NodeSessionCache.Set(nodeId, ns, cache.DefaultExpiration)
		return ns
	}

	return nil
}

func (h *PfAcct) deleteNodeSessionFromCache(sessionId uint64) {
	nodeId := formatNodeId(sessionId)
	h.NodeSessionCache.Delete(nodeId)
}
