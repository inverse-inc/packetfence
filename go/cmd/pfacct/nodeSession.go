package main

import (
	cache "github.com/fdurand/go-cache"
	"strconv"
)

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
		return i.(*nodeSession)
	}

	return nil
}

func (h *PfAcct) deleteNodeSessionFromCache(sessionId uint64) {
	nodeId := formatNodeId(sessionId)
	h.NodeSessionCache.Delete(nodeId)
}
