package main

import (
	"context"
	"database/sql"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/go-utils/mac"
)

// Native ports of the per-packet primitives historically performed by
// httpd.aaa's radius_accounting handler (pf::radius::accounting and
// pf::api::update_ip4log). Running them here keeps node.last_seen and ip4log
// fresh on every accounting packet even when pfacct_rate_limit suppresses the
// notification to httpd.aaa, and removes recurring per-packet mod_perl work.

// updateNodeLastSeen refreshes node.last_seen for the MAC, at most once per
// rate-limit TTL per MAC. Like pf::node::node_update_last_seen it only
// updates an existing node row; node creation stays with the registration
// paths.
func (h *PfAcct) updateNodeLastSeen(ctx context.Context, m mac.Mac) {
	key := m.String()
	if _, found := h.LastSeenCache.Get(key); found {
		return
	}
	h.LastSeenCache.Set(key, 1, cache.DefaultExpiration)

	if _, err := h.nodeUpdateLastSeen.Exec(key); err != nil {
		logError(ctx, "nodeUpdateLastSeen: "+err.Error())
	}
}

// updateIp4log mirrors pf::api::update_ip4log for accounting packets: close
// the previous ip4log entry when the MAC moved to a new IP, make sure the
// node row exists (ip4log's foreign key), then upsert the ip4log entry.
// Accounting carries no lease length, so like the Perl path the entry is
// opened with the zero end_time. Each MAC/IP pair is written at most once per
// rate-limit TTL; an IP change uses a fresh cache key and goes through
// immediately.
func (h *PfAcct) updateIp4log(ctx context.Context, m mac.Mac, framedIP string) {
	if !h.UpdateIplogWithAccounting {
		return
	}

	if framedIP == "" || framedIP == "0.0.0.0" {
		return
	}

	macStr := m.String()
	key := macStr + "|" + framedIP
	if _, found := h.Ip4logCache.Get(key); found {
		return
	}
	h.Ip4logCache.Set(key, 1, cache.DefaultExpiration)

	var oldIP string
	err := h.ip4logMac2Ip.QueryRow(macStr).Scan(&oldIP)
	if err != nil && err != sql.ErrNoRows {
		logError(ctx, "ip4logMac2Ip: "+err.Error())
	}

	if oldIP != "" && oldIP != framedIP {
		logInfo(ctx, "oldip ("+oldIP+") and newip ("+framedIP+") are different for "+macStr+" - closing ip4log entry")
		h.Ip4logCache.Delete(macStr + "|" + oldIP)
		if _, err := h.ip4logClose.Exec(oldIP); err != nil {
			logError(ctx, "ip4logClose: "+err.Error())
		}
	}

	if _, err := h.nodeAddSimple.Exec(macStr); err != nil {
		logError(ctx, "nodeAddSimple: "+err.Error())
	}

	if _, err := h.ip4logOpen.Exec(macStr, framedIP); err != nil {
		logError(ctx, "ip4logOpen: "+err.Error())
	}
}
