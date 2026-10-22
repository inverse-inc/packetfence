package main

import (
	"time"
)

const balancesInUseRefreshInterval = 5 * time.Minute

// balanceGateNow is time.Now, indirected so a test can observe what is already
// published when the instant is read. The ordering in setBalancesInUse is the
// whole point of that field, and the window a wrong order opens is far too
// narrow to catch by racing goroutines against it.
var balanceGateNow = time.Now

// anyNodeBalancesQuery probes whether any node carries a time or bandwidth
// balance. One predicate rather than two EXISTS subqueries: neither column is
// indexed, and the case this gate optimises for (no balances anywhere) is the
// one that cannot short-circuit, so two subqueries scan the node table twice.
const anyNodeBalancesQuery = `SELECT EXISTS(SELECT 1 FROM node WHERE time_balance IS NOT NULL OR bandwidth_balance IS NOT NULL)`

// refreshBalancesInUse probes whether any node currently carries a time or
// bandwidth balance. When none do (the common case), the per-packet balance
// accounting in handleAccountingRequest is skipped entirely: every statement
// it runs filters on the balance being NOT NULL and is a guaranteed no-op,
// yet together they cost several node-table SELECTs and two UPDATEs per
// accounting packet. Fails open: if the probe errors the balance path stays on.
//
// The query is issued directly rather than through RadiusStatements. It runs
// once per refresh interval, so preparing it buys nothing, and a prepared
// statement would have to be read while setupStmt's retry goroutine may still
// be writing the pointer.
func (h *PfAcct) refreshBalancesInUse() {
	if h.Db == nil {
		h.setBalancesInUse(true)
		return
	}

	var inUse bool
	if err := h.Db.QueryRow(anyNodeBalancesQuery).Scan(&inUse); err != nil {
		logError(h.LoggerCtx, "anyNodeBalances: "+err.Error())
		inUse = true
	}

	h.setBalancesInUse(inUse)
}

// setBalancesInUse records the flag and, when the gate reopens after having
// been shut, the instant it did. Sessions already in flight then have no
// NodeSessionCache entry while pfacct has no accounting at all for the period
// the gate was shut, so that instant bounds what may be charged for them; see
// handleTimeBalance. balancesInUse starts out true, so a deployment that has
// balances from the start never records an instant and keeps the pre-existing
// behaviour exactly.
func (h *PfAcct) setBalancesInUse(inUse bool) {
	if !inUse {
		h.balancesInUse.Store(false)
		return
	}

	// Record the instant before publishing the gate, never after: a worker that
	// sees balancesInUse true while balancesEnabledAt is still 0 gets no cap
	// from untrackedChargeCap and charges the whole AcctSessionTime -- the very
	// over-charge the cap exists to prevent. Only refreshBalancesInUse calls
	// this, from the refresher goroutine or before it starts, so a plain
	// load/store pair is enough; a CAS would still leave the same window.
	if h.balancesInUse.Load() {
		return
	}

	h.balancesEnabledAt.Store(balanceGateNow().Unix())
	h.balancesInUse.Store(true)
}

// capCharge clamps a charge to what may be billed since the balance gate last
// reopened. While the gate was shut pfacct processed no accounting at all, so
// neither the raw AcctSessionTime nor an offset kept from before the shutdown
// says anything about that period; charging it would zero a balance that was
// only just assigned. Returns the charge untouched until the gate has actually
// reopened after being shut (see untrackedChargeCap), so a deployment that has
// carried balances all along is unaffected.
func (h *PfAcct) capCharge(charge int64) int64 {
	if cap, capped := h.untrackedChargeCap(); capped && charge > cap {
		return cap
	}

	return charge
}

// untrackedChargeCap returns the most that may be charged for a session pfacct
// holds no NodeSessionCache entry for, and whether such a cap applies at all.
// It applies only once the gate has actually reopened after being shut: before
// that there is no cap and sessions are charged as they always were.
func (h *PfAcct) untrackedChargeCap() (int64, bool) {
	since := h.balancesEnabledAt.Load()
	if since == 0 {
		return 0, false
	}

	elapsed := balanceGateNow().Unix() - since
	if elapsed < 0 {
		elapsed = 0
	}

	return elapsed, true
}

// startBalancesInUseRefresher primes the balances-in-use flag and keeps it
// fresh; a balance assigned to a node is picked up within one refresh
// interval. Stop it with stopBalancesInUseRefresher.
func (h *PfAcct) startBalancesInUseRefresher() {
	h.refreshBalancesInUse()

	h.balancesRefresherStop = make(chan struct{})
	stop := h.balancesRefresherStop
	go func() {
		ticker := time.NewTicker(balancesInUseRefreshInterval)
		defer ticker.Stop()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				h.refreshBalancesInUse()
			}
		}
	}()
}

// stopBalancesInUseRefresher stops the goroutine started by
// startBalancesInUseRefresher. Safe to call more than once, and safe to call
// when the refresher was never started.
func (h *PfAcct) stopBalancesInUseRefresher() {
	h.balancesRefresherStopOnce.Do(func() {
		if h.balancesRefresherStop != nil {
			close(h.balancesRefresherStop)
		}
	})
}
