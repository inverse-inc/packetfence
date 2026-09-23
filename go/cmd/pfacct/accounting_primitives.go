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
//
// Returns whether last_seen is pfacct's business for this packet: true when
// the row was refreshed or is already fresh within the TTL, false when nothing
// was written. The caller advertises only what is true to the AAA layer, so a
// packet pfacct could not write keeps the httpd.aaa fallback it always had.
func (h *PfAcct) updateNodeLastSeen(ctx context.Context, m mac.Mac) bool {
	key := m.String()
	if _, found := h.LastSeenCache.Get(key); found {
		return true
	}

	res, err := h.nodeUpdateLastSeen.Exec(key)
	if err != nil {
		// The key is only cached once the write lands, so a transient failure
		// is retried by the next packet instead of freezing last_seen for a
		// full TTL.
		logError(ctx, "nodeUpdateLastSeen: "+err.Error())
		return false
	}

	// An UPDATE that matches no row is not an error, it means the node does not
	// exist yet (node creation belongs to the registration paths). Caching the
	// key then would suppress last_seen for a whole TTL for a node registered
	// moments later, so leave it uncached and let the AAA layer try. Same
	// treatment when the row was found but unchanged, which is what a second
	// write inside the same second looks like: the cost is one redundant Perl
	// write, the behaviour pfacct had before this branch.
	affected, err := res.RowsAffected()
	if err != nil || affected == 0 {
		return false
	}

	h.LastSeenCache.Set(key, 1, cache.DefaultExpiration)
	return true
}

// updateIp4log mirrors pf::api::update_ip4log for accounting packets: close
// the previous ip4log entry when the MAC moved to a new IP, make sure the
// node row exists (ip4log's foreign key), then upsert the ip4log entry.
// Accounting carries no lease length, so like the Perl path the entry is
// opened with the zero end_time. Each MAC/IP pair is written at most once per
// rate-limit TTL; an IP change uses a fresh cache key and goes through
// immediately.
//
// Returns whether ip4log is pfacct's business for this packet. Every case it
// declines -- the feature being off, a lookup source it cannot reproduce, an
// address pf::ip4log would reject, a statement that failed -- returns false so
// the caller leaves the primitive to httpd.aaa for that packet rather than
// having both sides skip it.
func (h *PfAcct) updateIp4log(ctx context.Context, m mac.Mac, framedIP string) bool {
	if !h.UpdateIplogWithAccounting {
		return false
	}

	// pf::ip4log::mac2ip asks pfdhcp for the current IP before falling back to
	// SQL when this is on, and the lease view can disagree with the table. The
	// native path has only the SQL half, so it could close a different entry
	// than update_ip4log would; leave the whole primitive to the AAA layer
	// instead of reproducing half of it.
	if h.Mac2ipLookup {
		return false
	}

	if framedIP == "" || framedIP == "0.0.0.0" {
		// pf::api::handle_accounting_metadata tests the address for truthiness
		// only, so Perl does call update_ip4log with 0.0.0.0: it closes the
		// previous entry and only then has pf::ip4log::open reject the new
		// address. Declining here keeps that behaviour available rather than
		// silently dropping the close.
		return false
	}

	macStr := m.String()
	key := macStr + "|" + framedIP
	if _, found := h.Ip4logCache.Get(key); found {
		return true
	}

	var oldIP string
	if err := h.ip4logMac2Ip.QueryRow(macStr).Scan(&oldIP); err != nil && err != sql.ErrNoRows {
		logError(ctx, "ip4logMac2Ip: "+err.Error())
		return false
	}

	if oldIP != "" && oldIP != framedIP {
		logInfo(ctx, "oldip ("+oldIP+") and newip ("+framedIP+") are different for "+macStr+" - closing ip4log entry")
		if _, err := h.ip4logClose.Exec(oldIP); err != nil {
			logError(ctx, "ip4logClose: "+err.Error())
			// Opening the new IP now would leave two entries active for the
			// MAC, and no later packet would repair it: ip4logMac2Ip returns
			// the most recently started entry, so the retry would find the one
			// just opened and never close the old one. Give up on the move and
			// let the AAA fallback redo both halves.
			return false
		}
		h.Ip4logCache.Delete(macStr + "|" + oldIP)
	}

	if _, err := h.nodeAddSimple.Exec(macStr); err != nil {
		logError(ctx, "nodeAddSimple: "+err.Error())
		return false
	}

	if _, err := h.ip4logOpen.Exec(macStr, framedIP); err != nil {
		logError(ctx, "ip4logOpen: "+err.Error())
		return false
	}

	// Cached only now that every statement has landed, so a transient failure
	// is retried by the next packet instead of freezing this MAC/IP pair for a
	// full TTL.
	h.Ip4logCache.Set(key, 1, cache.DefaultExpiration)
	return true
}
