package main

import (
	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/mac"
	"strconv"
)

type nodeSession struct {
	timeBalance      int64
	bandwidthBalance int64
}

func formatNodeId(mac mac.Mac, tenant int) string {
	return strconv.FormatUint(mac.NodeId(uint16(tenant)), 36)
}

func (h *PfAcct) setNodeSessionCache(macStr string, tenant int, ns *nodeSession) {
	mac, _ := mac.NewFromString(macStr)
	nodeId := formatNodeId(mac, tenant)
	h.NodeSessionCache.Set(nodeId, ns, cache.DefaultExpiration)
}

func (h *PfAcct) getNodeSessionFromCache(macStr string, tenant int) *nodeSession {
	mac, _ := mac.NewFromString(macStr)
	nodeId := formatNodeId(mac, tenant)
	if i, found := h.NodeSessionCache.Get(nodeId); found {
		return i.(*nodeSession)
	}

	return nil
}

func (h *PfAcct) deleteNodeSessionFromCache(macStr string, tenant int) {
	mac, _ := mac.NewFromString(macStr)
	nodeId := formatNodeId(mac, tenant)
	h.NodeSessionCache.Delete(nodeId)
}
