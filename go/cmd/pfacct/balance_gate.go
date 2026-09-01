package main

import (
	"time"
)

const balancesInUseRefreshInterval = 5 * time.Minute

// refreshBalancesInUse probes whether any node currently carries a time or
// bandwidth balance. When none do (the common case), the per-packet balance
// accounting in handleAccountingRequest is skipped entirely: every statement
// it runs filters on the balance being NOT NULL and is a guaranteed no-op,
// yet together they cost several node-table SELECTs and two UPDATEs per
// accounting packet. Fails open: with the probe unavailable or erroring, the
// balance path stays on.
func (h *PfAcct) refreshBalancesInUse() {
	if h.anyNodeBalances == nil {
		h.balancesInUse.Store(true)
		return
	}

	var inUse bool
	if err := h.anyNodeBalances.QueryRow().Scan(&inUse); err != nil {
		logError(h.LoggerCtx, "anyNodeBalances: "+err.Error())
		inUse = true
	}
	h.balancesInUse.Store(inUse)
}

// startBalancesInUseRefresher primes the balances-in-use flag and keeps it
// fresh; a balance assigned to a node is picked up within one refresh
// interval.
func (h *PfAcct) startBalancesInUseRefresher() {
	h.refreshBalancesInUse()
	go func() {
		for {
			time.Sleep(balancesInUseRefreshInterval)
			h.refreshBalancesInUse()
		}
	}()
}
